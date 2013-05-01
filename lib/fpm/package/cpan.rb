require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

class FPM::Package::CPAN < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:npm_foo]
  option "--perl-bin", "PERL_EXECUTABLE",
    "The path to the perl executable you wish to run.", :default => "perl"
  option "--cpanm-bin", "CPANM_EXECUTABLE",
    "The path to the cpanm executable you wish to run.", :default => "cpanm"
  option "--package-name-prefix", "NAME_PREFIX", "Name to prefix the package " \
    "name with.", :default => "perl"
  option "--test", :flag, "Run the tests before packaging?", :default => true

  private
  def input(package)
    require "ftw" # for http access
    require "json"

    agent = FTW::Agent.new
    result = search(package, agent)
    tarball = download(result, agent)
    moduledir = unpack(tarball)

    # Read package metadata (name, version, etc)
    if File.exists?(File.join(moduledir, "META.json"))
      metadata = JSON.parse(File.read(File.join(moduledir, ("META.json"))))
    elsif File.exists?(File.join(moduledir, ("META.yml")))
      require "yaml"
      metadata = YAML.load_file(File.join(moduledir, ("META.yml")))
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

    # Not all things have 'author' listed.
    self.vendor = metadata["author"].join(", ") if metadata.include?("author")
    self.url = metadata["resources"]["homepage"] rescue "unknown"

    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # Install any build/configure dependencies with cpanm.
    # We'll install to a temporary directory.
    @logger.info("Installing any build or configure dependencies")
    safesystem(attributes[:cpan_cpanm_bin], "-L", build_path("cpan"), moduledir)

    if !attributes[:no_auto_depends?]
      metadata["requires"].each do |dep_name, version|
        dep = search(dep_name, agent)
        name = fix_name(dep["name"])
        require "pry"; binding.pry
        if version.to_s == "0"
          # Assume 'Foo = 0' means any version?
          self.dependencies << "#{name}"
        else
          self.dependencies << "#{name} = #{version}"
        end
      end
    end #no_auto_depends

    ::Dir.chdir(moduledir) do
      # TODO(sissel): install build and config dependencies to resolve
      # build/configure requirements.
      # META.yml calls it 'configure_requires' and 'build_requires'
      # META.json calls it prereqs/build and prereqs/configure
 
      prefix = attributes[:prefix] || "/usr/local"
      # TODO(sissel): Set default INSTALL path?
      # perl -e 'use Config; print "$Config{sitelib}"'
      safesystem(attributes[:cpan_perl_bin],
                 "-Mlocal::lib=#{build_path("cpan")}",
                 "Makefile.PL",
                 "PREFIX=#{prefix}",
                 # Have to specify INSTALL_BASE as empty otherwise
                 # Makefile.PL lies and claims we've set both PREFIX and
                 # INSTALL_BASE.
                 "INSTALL_BASE="
                )

      make = [ "make" ]

      safesystem(*make)
      safesystem(*(make + ["test"])) if attributes[:cpan_test?]
      safesystem(*(make + ["DESTDIR=#{staging_path}", "install"]))
    end
  end

  def unpack(tarball)
    directory = build_path("module")
    ::Dir.mkdir(directory)
    args = [ "-C", directory, "-zxf", tarball,
      "--strip-components", "1" ]
    safesystem("tar", *args)
    return directory
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
