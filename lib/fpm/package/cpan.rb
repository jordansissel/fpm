require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"
require "find"
require "pathname"

class FPM::Package::CPAN < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:npm_foo]
  option "--perl-bin", "PERL_EXECUTABLE",
    "The path to the perl executable you wish to run.", :default => "perl"

  option "--cpanm-bin", "CPANM_EXECUTABLE",
    "The path to the cpanm executable you wish to run.", :default => "cpanm"

  option "--mirror", "CPAN_MIRROR",
    "The CPAN mirror to use instead of the default."

  option "--mirror-only", :flag,
    "Only use the specified mirror for metadata.", :default => false

  option "--package-name-prefix", "NAME_PREFIX",
    "Name to prefix the package name with.", :default => "perl"

  option "--test", :flag,
    "Run the tests before packaging?", :default => true

  option "--verbose", :flag,
    "Produce verbose output from cpanm?", :default => false

  option "--perl-lib-path", "PERL_LIB_PATH",
    "Path of target Perl Libraries"

  option "--sandbox-non-core", :flag,
    "Sandbox all non-core modules, even if they're already installed", :default => true

  option "--cpanm-force", :flag,
    "Pass the --force parameter to cpanm", :default => false

  private
  def input(package)
    #if RUBY_VERSION =~ /^1\.8/
      #raise FPM::Package::InvalidArgument,
        #"Sorry, CPAN support requires ruby 1.9 or higher. You have " \
        #"#{RUBY_VERSION}. If this negatively impacts you, please let " \
        #"me know by filing an issue: " \
        #"https://github.com/jordansissel/fpm/issues"
    #end
    #require "ftw" # for http access
    require "net/http"
    require "json"

    if File.exist?(package)
      moduledir = package
      result = {}
    else
      result = search(package)
      tarball = download(result, version)
      moduledir = unpack(tarball)
    end

#    logger.info("[[[ DEBUG ]]] Received metadata from metacpan: ", :metadata => result)
#    logger.info("[[[ DEBUG ]]] in cpan::input(), received result['module'] from metacpan: ", :result_module => result["module"])

    # Read package metadata (name, version, etc)
    if File.exist?(File.join(moduledir, "META.json"))
      local_metadata = JSON.parse(File.read(File.join(moduledir, ("META.json"))))
    elsif File.exist?(File.join(moduledir, ("META.yml")))
      require "yaml"
      local_metadata = YAML.load_file(File.join(moduledir, ("META.yml")))
    elsif File.exist?(File.join(moduledir, "MYMETA.json"))
      local_metadata = JSON.parse(File.read(File.join(moduledir, ("MYMETA.json"))))
    elsif File.exist?(File.join(moduledir, ("MYMETA.yml")))
      require "yaml"
      local_metadata = YAML.load_file(File.join(moduledir, ("MYMETA.yml")))
    end

    # Merge the MetaCPAN query result and the metadata pulled from the local
    # META file(s).  The local data overwrites the query data for all keys the
    # two hashes have in common.  Merge with an empty hash if there was no
    # local META file.
    metadata = result.merge(local_metadata || {})

#    logger.info("[[[ DEBUG ]]] in cpan::input(), have merged metadata: ", :metadata => metadata)
#    logger.info("[[[ DEBUG ]]] in cpan::input(), have merged metadata['module'] ", :metadata_module => metadata["module"])

    if metadata.empty?
      raise FPM::InvalidPackageConfiguration,
        "Could not find package metadata. Checked for META.json, META.yml, and MetaCPAN API data"
    end

    self.version = metadata["version"]
    # WBRASWELL 20180904 2018.247: strip leading 'v' from version strings for proper package dependency checking
    if (self.version.kind_of?(String) and (self.version[0] == 'v'))
      logger.warn("Package version '#{self.version}' includes 'v' prefix, removing")
      self.version[0] = ''
    end

    self.description = metadata["abstract"]

    self.license = case metadata["license"]
      when Array; metadata["license"].first
      when nil; "unknown"
      else; metadata["license"]
    end

    # WBRASWELL 20180827 2018.239: must search by distribution (not by package/module) to find "provides" data
    unless metadata["distribution"].nil?
      logger.info("Setting package name from 'distribution'",
                   :distribution => metadata["distribution"])
      self.name = fix_name(metadata["distribution"])
      dist_metadata = search_dist(metadata["distribution"])
    else
      raise FPM::InvalidPackageConfiguration,
        "Could not find distribution name in package metadata, must have distribution name to search for 'provides' metadata"
#      logger.info("Setting package name from 'name'",
#                   :name => metadata["name"])
#      self.name = fix_name(metadata["name"])
    end

#    logger.info("[[[ DEBUG ]]] in cpan::input(), have distribution metadata: ", :dist_metadata => dist_metadata)
#    logger.info("[[[ DEBUG ]]] in cpan::input(), have distribution metadata['provides'] ", :dist_metadata_provides => dist_metadata["provides"])

#    logger.info("[[[ DEBUG ]]] in cpan::input(), have distribution metadata: ", :dist_metadata => dist_metadata)

    # WBRASWELL 20180827 2018.239: must search by distribution (not by package/module) to find "provides" data
    unless dist_metadata["provides"].nil?

      # convert provides from array to hash for quick lookup during iteration
      dist_metadata_provides = Hash[dist_metadata["provides"].collect { |item| [item, ""] } ]
#      logger.info("[[[ DEBUG ]]] in cpan::input(), have dist_metadata_provides: ", :dist_metadata_provides => dist_metadata_provides)
#      logger.info("[[[ DEBUG ]]] in cpan::input(), have self.name: ", :self_name => self.name)
#      logger.info("[[[ DEBUG ]]] in cpan::input(), have metadata['distribution']: ", :metadata_distribution => metadata["distribution"])

      # call metacpan API to find all modules belonging to distribution
      metacpan_search_url = "https://fastapi.metacpan.org/v1/module/_search"
      metacpan_search_query = <<-EOL
{
    "query" : {
        "constant_score" : {
            "filter" : {
                "exists" : { "field" : "module" }
            }
        }
    },
    "size": 5000,
    "_source": [ "name", "module.name", "module.version" ],
    "filter": {
        "and": [
            { "term": { "distribution": "#{metadata["distribution"]}" } },
            { "term": { "maturity": "released" } },
            { "term": { "status": "latest" } }
        ]
    }
}
EOL

      begin
        search_response = httppost(metacpan_search_url,metacpan_search_query)
      rescue Net::HTTPServerException => e
        logger.error("metacpan release query failed.", :error => e.message,
                      :url => metacpan_search_url)
         raise FPM::InvalidPackageConfiguration, "metacpan release query failed"
      end

      json_modules = search_response.body
      json_modules_parsed = JSON.parse(json_modules)

#      logger.info("[[[ DEBUG ]]] in cpan::input(), have json_modules: ", :json_modules => json_modules)
#      logger.info("[[[ DEBUG ]]] in cpan::input(), have json_modules_parsed: ", :json_modules_parsed => json_modules_parsed)
#      require 'pp'
#      pp json_modules_parsed

      # loop through all modules belonging to distribution, find those present in provides
      json_modules_parsed['hits']['hits'].each do |m|
        # each .pm module file may contain multiple packages, iterate through each
        m['_source']['module'].each do |package|
          # only access the package with the correct name
          if dist_metadata_provides.key?(package["name"])
            # check is package has version or not
            if ((package.key?("version")) && !(package["version"].nil?))
              # use normal stringified "version" rather than "version_numified", which may contain invalid scientific notation or 0 instead of blank
              dist_metadata_provides[package["name"]] = package["version"]
              # WBRASWELL 20180904 2018.247: strip leading 'v' from version strings for proper package dependency checking
              if (dist_metadata_provides[package["name"]].kind_of?(String) and (dist_metadata_provides[package["name"]][0] == 'v'))
                logger.warn("Package provides '#{package["name"]}' version '#{dist_metadata_provides[package["name"]]}' includes 'v' prefix, removing")
                dist_metadata_provides[package["name"]][0] = ''
              end  # if, version string starts with letter 'v'
            else
              # some packages have no version, but are still valid packages
              dist_metadata_provides[package["name"]] = "-1"
            end  # if, provides has version
            # DEV NOTE: each .pm module file may contain multiple packages which are provided, do NOT break after finding one
#            break
          end  # if, module name matches
        end  # do loop, packages in module
      end  # do loop, modules in dist

      # actually create the provides, in the order given by the metacpan query
      dist_metadata["provides"].each do |provide|
        if (dist_metadata_provides[provide] == "")
           raise FPM::InvalidPackageConfiguration, "metacpan module query did not contain version info for package " + provide
        elsif (dist_metadata_provides[provide] == "-1")
          self.provides << cap_name(provide)
        else
          self.provides << cap_name(provide) + " = " + dist_metadata_provides[provide]
        end  # if, version was found
      end  # do loop, provides in dist

    end  # unless, dist has empty provides

    # author is not always set or it may be a string instead of an array
    self.vendor = case metadata["author"]
      when String; metadata["author"]
      when Array; metadata["author"].join(", ")
      # for Class::Data::Inheritable and others with blank 'author' field, fix "Invalid package configuration: Unexpected CPAN 'author' field type: NilClass. This is a bug."
      when NilClass; "No Vendor Or Author Provided"
      else
        raise FPM::InvalidPackageConfiguration, "Unexpected CPAN 'author' field type: #{metadata["author"].class}. This is a bug."
    end if metadata.include?("author")

    self.url = metadata["resources"]["homepage"] rescue "unknown"

    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # Install any build/configure dependencies with cpanm.
    # We'll install to a temporary directory.
    logger.info("Installing any build or configure dependencies")

    if attributes[:cpan_sandbox_non_core?]
      cpanm_flags = ["-L", build_path("cpan"), moduledir]
    else
      cpanm_flags = ["-l", build_path("cpan"), moduledir]
    end

    # This flag causes cpanm to ONLY download dependencies, skipping the target
    # module itself.  This is fine, because the target module has already been
    # downloaded, and there's no need to download twice, test twice, etc.
    cpanm_flags += ["--installdeps"]
    cpanm_flags += ["-n"] if !attributes[:cpan_test?]
    cpanm_flags += ["--mirror", "#{attributes[:cpan_mirror]}"] if !attributes[:cpan_mirror].nil?
    cpanm_flags += ["--mirror-only"] if attributes[:cpan_mirror_only?] && !attributes[:cpan_mirror].nil?
    cpanm_flags += ["--force"] if attributes[:cpan_cpanm_force?]
    cpanm_flags += ["--verbose"] if attributes[:cpan_verbose?]

    # Run cpanm with stdin enabled so that ExtUtils::MakeMaker does not prompt user for input
#    safesystem(attributes[:cpan_cpanm_bin], *cpanm_flags)
    safesystemin("", attributes[:cpan_cpanm_bin], *cpanm_flags)

    if !attributes[:no_auto_depends?]
     found_dependencies = {}
     if metadata["requires"]
       found_dependencies.merge!(metadata["requires"])
     end
     if metadata["prereqs"]
       if metadata["prereqs"]["runtime"]
         if metadata["prereqs"]["runtime"]["requires"]
           found_dependencies.merge!(metadata["prereqs"]["runtime"]["requires"])
         end
       end
     end
     unless found_dependencies.empty?
       found_dependencies.each do |dep_name, version|
          # Special case for representing perl core as a version.
          if dep_name == "perl"
            m = version.to_s.match(/^(\d)\.(\d{3})(\d{3})$/)
            if m
               version = m[1] + '.' + m[2].sub(/^0*/, '') + '.' + m[3].sub(/^0*/, '')
            end
            self.dependencies << "#{dep_name} >= #{version}"
            next
          end
          dep = search(dep_name)

          name = cap_name(dep_name)

          if version.to_s == "0"
            # Assume 'Foo = 0' means any version?
            self.dependencies << "#{name}"
          else
            # The 'version' string can be something complex like:
            #   ">= 0, != 1.0, != 1.2"
            # If it is not specified explicitly, require the given
            # version or newer, as that is all CPAN itself enforces
            if version.is_a?(String)
              version.split(/\s*,\s*/).each do |v|
                if v =~ /\s*[><=]/
                  self.dependencies << "#{name} #{v}"
                else
                  self.dependencies << "#{name} >= #{v}"
                end
              end
            else
              self.dependencies << "#{name} >= #{version}"
            end
          end
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

      # Try Makefile.PL, Build.PL
      #
      if File.exist?("Build.PL")
        # Module::Build is in use here; different actions required.
#        safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
        safesystemin("", attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "Build.PL")
#        safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
        safesystemin("", attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "./Build")

        if attributes[:cpan_test?]
#        safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
          safesystemin("", attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "./Build", "test")
        end
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
          safesystem("./Build install --install_path lib=#{perl_lib_path} \
                     --destdir #{staging_path} --prefix #{prefix} --destdir #{staging_path}")
        else
           safesystem("./Build", "install",
                     "--prefix", prefix, "--destdir", staging_path,
                     # Empty install_base to avoid local::lib being used.
                     "--install_base", "")
        end
      elsif File.exist?("Makefile.PL")
        if attributes[:cpan_perl_lib_path]
          perl_lib_path = attributes[:cpan_perl_lib_path]
#          safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
          safesystemin("", attributes[:cpan_perl_bin],
                     "-Mlocal::lib=#{build_path("cpan")}",
                     "Makefile.PL", "PREFIX=#{prefix}", "LIB=#{perl_lib_path}",
                     # Empty install_base to avoid local::lib being used.
                     "INSTALL_BASE=")
        else
#          safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
          safesystemin("", attributes[:cpan_perl_bin],
                     "-Mlocal::lib=#{build_path("cpan")}",
                     "Makefile.PL", "PREFIX=#{prefix}",
                     # Empty install_base to avoid local::lib being used.
                     "INSTALL_BASE=")
        end
        make = [ "env", "PERL5LIB=#{build_path("cpan/lib/perl5")}", "make" ]
        safesystem(*make)
        safesystem(*(make + ["test"])) if attributes[:cpan_test?]
        safesystem(*(make + ["DESTDIR=#{staging_path}", "install"]))


      else
        raise FPM::InvalidPackageConfiguration,
          "I don't know how to build #{name}. No Makefile.PL nor " \
          "Build.PL found"
      end

      # Fix any files likely to cause conflicts that are duplicated
      # across packages.
      # https://github.com/jordansissel/fpm/issues/443
      # https://github.com/jordansissel/fpm/issues/510
      glob_prefix = attributes[:cpan_perl_lib_path] || prefix
      ::Dir.glob(File.join(staging_path, glob_prefix, "**/perllocal.pod")).each do |path|
        logger.debug("Removing useless file.",
                      :path => path.gsub(staging_path, ""))
        File.unlink(path)
      end

      # Remove useless .packlist files and their empty parent folders
      # https://github.com/jordansissel/fpm/issues/1179
      ::Dir.glob(File.join(staging_path, glob_prefix, "**/.packlist")).each do |path|
        logger.debug("Removing useless file.",
                      :path => path.gsub(staging_path, ""))
        File.unlink(path)
        Pathname.new(path).parent.ascend do |parent|
          if ::Dir.entries(parent).sort == ['.', '..'].sort
            FileUtils.rmdir parent
          else
            break
          end
        end
      end
    end


    # TODO(sissel): figure out if this perl module compiles anything
    # and set the architecture appropriately.
    self.architecture = "all"

    # Find any shared objects in the staging directory to set architecture as
    # native if found; otherwise keep the 'all' default.
    Find.find(staging_path) do |path|
      if path =~ /\.so$/
        logger.info("Found shared library, setting architecture=native",
                     :path => path)
        self.architecture = "native"
      end
    end
  end

  def unpack(tarball)
    directory = build_path("module")
    ::Dir.mkdir(directory)
    args = [ "-C", directory, "-zxf", tarball,
#      "--strip-components", "1" ]       # fails    on removing leading ./Foo/ in tarball paths
      %q{--transform=s,[./]*[^/]*/,,} ]  # succeeds on removing leading ./Foo/ or /Foo/ or Foo/
    safesystem("tar", *args)
    return directory
  end

  def download(metadata, cpan_version=nil)

    distribution = metadata["distribution"]
    author = metadata["author"]

    logger.info("Downloading perl module",
                 :distribution => distribution,
                 :version => cpan_version)

    # default to latest version unless we specify one
    if cpan_version.nil?
      self.version = "#{metadata["version"]}"
    else
      self.version = "#{cpan_version}"
    end

    # Search metacpan to get download URL for this version of the module
    metacpan_search_url = "https://fastapi.metacpan.org/v1/release/_search"
    metacpan_search_query = '{"fields":["download_url"],"filter":{"term":{"name":"' + "#{distribution}-#{self.version}" + '"}}}'
    begin
      search_response = httppost(metacpan_search_url,metacpan_search_query)
    rescue Net::HTTPServerException => e
      logger.error("metacpan release query failed.", :error => e.message,
                    :url => metacpan_search_url)
      raise FPM::InvalidPackageConfiguration, "metacpan release query failed"
    end

    data = search_response.body
    release_metadata = JSON.parse(data)

    download_url = release_metadata['hits']['hits'][0]['fields']['download_url']
    download_path = URI.parse(download_url).path
    tarball = File.basename(download_path)

    url_base = "http://www.cpan.org/"
    url_base = "#{attributes[:cpan_mirror]}" if !attributes[:cpan_mirror].nil?

    url = "#{url_base}#{download_path}"
    logger.debug("Fetching perl module", :url => url)

    begin
      response = httpfetch(url)
    rescue Net::HTTPServerException => e
      #logger.error("Download failed", :error => response.status_line,
                    ##:url => url)
      logger.error("Download failed", :error => e, :url => url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    File.open(build_path(tarball), "w") do |fd|
      #response.read_body { |c| fd.write(c) }
      fd.write(response.body)
    end
    return build_path(tarball)
  end # def download

  def search(package)

    logger.info("Asking metacpan about a module", :module => package)
    metacpan_url = "https://fastapi.metacpan.org/v1/module/" + package
    begin
      response = httpfetch(metacpan_url)
    rescue Net::HTTPServerException => e
      #logger.error("metacpan query failed.", :error => response.status_line,
                    ##:module => package, :url => metacpan_url)
      logger.error("metacpan query failed.", :error => e.message,
                    :module => package, :url => metacpan_url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    #data = ""
    #response.read_body { |c| p c; data << c }
    data = response.body
    metadata = JSON.parse(data)
    return metadata
  end # def metadata

  # WBRASWELL 20180827 2018.239: must search by distribution (not by package/module) to find "provides" data
  def search_dist(distribution)

    logger.info("Asking metacpan about a distribution", :dist => distribution)
    metacpan_url = "https://fastapi.metacpan.org/v1/release/" + distribution
    begin
      response = httpfetch(metacpan_url)
    rescue Net::HTTPServerException => e
      #logger.error("metacpan query failed.", :error => response.status_line,
                    ##:dist => distribution, :url => metacpan_url)
      logger.error("metacpan query failed.", :error => e.message,
                    :dist => distribution, :url => metacpan_url)
      raise FPM::InvalidPackageConfiguration, "metacpan query failed"
    end

    #data = ""
    #response.read_body { |c| p c; data << c }
    data = response.body
    metadata = JSON.parse(data)
    return metadata
  end # def metadata

  def cap_name(name)
    return "perl(" + name.gsub("-", "::") + ")"
  end # def cap_name

  def fix_name(name)
    case name
      when "perl"; return "perl"
      else; return [attributes[:cpan_package_name_prefix], name].join("-").gsub("::", "-")
    end
  end # def fix_name

  def httpfetch(url)
    uri = URI.parse(url)
    if ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      http = Net::HTTP.Proxy(proxy.host,proxy.port,proxy.user,proxy.password).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end
    http.use_ssl = uri.scheme == 'https'
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    case response
      when Net::HTTPSuccess; return response
      when Net::HTTPRedirection; return httpfetch(response["location"])
      else; response.error!
    end
  end

  def httppost(url, body)
    uri = URI.parse(url)
    if ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      http = Net::HTTP.Proxy(proxy.host,proxy.port,proxy.user,proxy.password).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end
    http.use_ssl = uri.scheme == 'https'
    response = http.post(uri.request_uri, body)
    case response
      when Net::HTTPSuccess; return response
      when Net::HTTPRedirection; return httppost(response["location"])
      else; response.error!
    end
  end

  public(:input)
end # class FPM::Package::NPM
