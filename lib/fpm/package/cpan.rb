require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

class FPM::Package::CPAN < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:npm_foo]
  option "--perl-bin", "PERL_EXECUTABLE",
    "The path to the perl executable you wish to run.", :default => "perl"

  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "perl"

  private
  def input(package)
    require "ftw" # for http access
    require "json"

    agent = FTW::Agent.new
    result = search(package, agent)
    tarball = download(result, agent)
    unpack(tarball)

    # TODO(sissel): read metadata froM META.json
    if File.exists?(build_path("META.json"))
      metadata = JSON.parse(File.read(build_path("META.json")))
    elsif File.exists?(build_path("META.yml"))
      require "yaml"
      metadata = YAML.load_file(build_path("META.yml"))
    else
      raise FPM::InvalidPackageConfiguration, 
        "Could not find package metadata. Checked for META.json and META.yml"
    end
    self.version = metadata["version"]
    self.description = metadata["abstract"]

    self.license = case metadata["license"]
      when Array; metadata["license"].first
      else; metadata["license"]
    end
    self.name = fix_name(metadata["name"])
    self.vendor = metadata["author"].join(", ")
    self.url = metadata["resources"]["homepage"]

    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # If it was yaml, dependencies will be at the top level
    # If it was json, the dependencies will be in the 'prereq' key
    # TODO(sissel): dependencies in metadata["prereqs"]["runtime"]["requires"] ?

    ::Dir.chdir(build_path) do
      # TODO(sissel): install build and config dependencies temporarily?
 
      safesystem(attributes[:cpan_perl_bin], "Makefile.PL")
      make = [ "make" ]
      make << "PREFIX=#{attributes[:prefix]}" unless attributes[:prefix].nil?

      safesystem(*make)
      safesystem(*(make + ["DESTDIR=#{staging_path}", "install"]))
    end
  end

  def unpack(tarball)
    args = [ "-C", build_path, "-zxf", tarball, "--strip-components", "1" ]
    safesystem("tar", *args)
  end

  def download(metadata, agent)
    distribution = metadata["distribution"]
    author = metadata["author"]
    @logger.info("Downloading perl module",
                 :distribution => distribution,
                 :version => version)

    # default to latest versionunless we specify one
    version = metadata["version"] if version.nil?

    tarball = "#{distribution}-#{version}.tar.gz"
    url = "http://search.cpan.org/CPAN/authors/id/#{author[0,1]}/#{author[0,2]}/#{author}/#{tarball}"
    response = agent.get!(url)
    if response.error?
      @logger.error("Download failed", :error => response.status_line,
                    :url => url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    File.open(build_path(tarball), "w") do |fd|
      response.read_body { |c| fd.write(c) }
    end
    return build_path(tarball)
  end # def download

  def search(package, agent)
    @logger.info("Asking metacpan about a module", :module => package)
    metacpan_url = "http://api.metacpan.org/v0/module/" + package
    response = agent.get!(metacpan_url)
    if response.error?
      @logger.error("metacpan query failed.", :error => response.status_line,
                    :module => package, :url => metacpan_url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    data = ""
    response.read_body { |c| data << c }
    metadata = JSON.parse(data)
    return metadata
  end # def metadata

  def fix_name(name)
    return [attributes[:cpan_package_name_prefix], name].join("-").gsub("::", "-")
  end # def fix_name

  public(:input)
end # class FPM::Package::NPM
