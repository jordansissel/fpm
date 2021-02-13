require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"
require "find"
require "pathname"
require "pp"  # TMP DEBUG, pretty print library

class FPM::Package::CPAN < FPM::Package
  # Flags '--foo-bar' will be accessable  as attributes[:cpan_foo_bar]
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

#    puts "[[[ DEBUG ]]] Received metadata from metacpan ="
#    pp result
#    puts "[[[ DEBUG ]]] in cpan::input(), received result['module'] from metacpan ="
#    pp result["module"]

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

#    puts "[[[ DEBUG ]]] in cpan::input(), have merged metadata ="
#    pp metadata
#    puts "[[[ DEBUG ]]] in cpan::input(), have merged metadata['module'] ="
#    pp metadata["module"]

    if metadata.empty?
      raise FPM::InvalidPackageConfiguration,
        "Could not find package metadata. Checked for META.json, META.yml, and MetaCPAN API data"
    end

    self.version = metadata["version"]

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

    puts "[[[ DEBUG ]]] in cpan::input(), have self.name = #{self.name}"
#    puts "[[[ DEBUG ]]] in cpan::input(), have distribution metadata ="
#    pp dist_metadata
#    puts "[[[ DEBUG ]]] in cpan::input(), have distribution metadata['provides'] ="
#    pp dist_metadata["provides"]

    # WBRASWELL 20180912 2018.255: convert version strings to conform with existing naming convention for proper package dependency checking

    # DEV NOTE, CORRELATION #ctf10: convert all versions before creating package, except single-life Perl core modules in distribution 'perl'; self distribution
    self.version = self.version.to_s
    if (self.name != 'perl')
      self_version_converted = convert_version(self.version, '')
      if (self.version != self_version_converted)
        logger.warn("Self distribution '#{self.name}' version '#{self.version}' converted to '#{self_version_converted}'")
        self.version = self_version_converted
      end  # if, self.version converted
    else
      puts "[[[ DEBUG ]]] in cpan::input(), self distribution is SINGLE-LIFE PERL CORE MODULE, do not convert"
    end  # if, distribution is not 'perl'

    # WBRASWELL 20180827 2018.239: must search by distribution (not by package/module) to find "provides" data
    unless dist_metadata["provides"].nil?

      # convert provides from array to hash for quick lookup during iteration
      dist_metadata_provides = Hash[dist_metadata["provides"].collect { |item| [item, ""] } ]
#      puts "[[[ DEBUG ]]] in cpan::input(), have dist_metadata_provides ="
#      pp dist_metadata_provides
#      puts "[[[ DEBUG ]]] in cpan::input(), have self.name = '#{self.name}'"
#      puts "[[[ DEBUG ]]] in cpan::input(), have metadata['distribution'] = '#{metadata["distribution"]}'"

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

#      puts "[[[ DEBUG ]]] in cpan::input(), have json_modules ="
#      pp json_modules
#      puts "[[[ DEBUG ]]] in cpan::input(), have json_modules_parsed ="
#      pp json_modules_parsed

      # loop through all modules belonging to distribution, find those present in provides
      json_modules_parsed['hits']['hits'].each do |m|
        # each .pm module file may contain multiple packages, iterate through each
        m['_source']['module'].each do |package|
#          puts "[[[ DEBUG ]]] in cpan::input(), top of provides loop for self.name = '#{self.name}', have package ="
#          pp package

          # only access the package with the correct name
          if dist_metadata_provides.key?(package["name"])
            # check is package has version or not
            if ((package.key?("version")) && !(package["version"].nil?))
              # use normal stringified "version" rather than "version_numified", which may contain invalid scientific notation or 0 instead of blank

              # DEV NOTE, CORRELATION #ctf10: convert all versions before creating package, except single-life Perl core modules in distribution 'perl'; provides
              package['version'] = package['version'].to_s
              if (self.name != 'perl')
                package_version_converted = convert_version(package['version'], '')
                if (package['version'] != package_version_converted)
                  logger.warn("Provides module '#{package['name']}' version '#{package['version']}' converted to '#{package_version_converted}'")
                  package['version'] = package_version_converted
                end  # if, package['version'] converted
              else
                puts "[[[ DEBUG ]]] in cpan::input(), in provides loop, provides is SINGLE-LIFE PERL CORE MODULE, do not convert"
              end  # if, distribution is not 'perl'

              dist_metadata_provides[package["name"]] = package["version"]

              puts "[[[ DEBUG ]]] in cpan::input(), in provides loop, have package['name'] = '#{package['name']}'"
              puts "[[[ DEBUG ]]] in cpan::input(), in provides loop, have package['version'] = '#{package['version']}'"

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

    # DEV NOTE, CORRELATION #ctf11: deps/requires which are single-life Perl core packages must conform to existing repo version formats
    perl_provides = run_repoquery_provides('perl')
    puts "[[[ DEBUG ]]] in cpan::input(), have perl_provides = "
    pp perl_provides

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
          puts "[[[ DEBUG ]]] in cpan::input(), top of deps/requires loop for dep_name = '#{dep_name}'"

          # Special case for representing perl core as a version.
          if dep_name == "perl"
            m = version.to_s.match(/^(\d)\.(\d{3})(\d{3})$/)
            if m
               version = m[1] + '.' + m[2].sub(/^0*/, '') + '.' + m[3].sub(/^0*/, '')
            end
            self.dependencies << "#{dep_name} >= #{version}"
            next
          end

# WBRASWELL 20180920 2018.263: dependencies version numbers must conform to format of actual module's version number as reported by metacpan
# [[[ BEGIN MODIFIED CODE ]]]

          dep_metadata = search(dep_name)
          dep_distribution = dep_metadata['distribution']
#          puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', have dep_metadata = "
#          pp dep_metadata
          puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', have dep_distribution = '#{dep_distribution}'"

          name = cap_name(dep_name)

          if version.to_s == "0"
            # Assume 'Foo = 0' means any version?
            self.dependencies << "#{name}"
          else

            # The 'version' string can be something complex like:
            #   ">= 0, != 1.0, != 1.2"
            # If it is not specified explicitly, require the given
            # version or newer, as that is all CPAN itself enforces
            if version.is_a?(String)  # version is string
              version.split(/\s*,\s*/).each do |v|
                puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', top of versions loop, have version = '#{version}'"

                if v =~ /\s*[><=]/  # version string includes comparator
                  v_comparator, v_version = v.split(/\s+/) 
                  # DEV NOTE, CORRELATION #ctf10: convert all versions before creating package, except single-life Perl core modules in distribution 'perl'; deps/requires
                  v_version = v_version.to_s
                  if (dep_distribution != 'perl')
                    v_version_converted = convert_version(v_version, '')
                    if (v_version != v_version_converted)
                      logger.warn("Required module '#{dep_name}' comparator version '#{v_comparator} #{v_version}' converted to '#{v_comparator} #{v_version_converted}'")
                      v_version = v_version_converted
                    end  # if, version converted
                  else
                    # DEV NOTE, CORRELATION #ctf11: deps/requires which are single-life Perl core packages must conform to existing repo version formats
                    puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', in versions loop, comparator version dep is SINGLE-LIFE PERL CORE MODULE, need convert"
                    if (not perl_provides.key?(dep_name))
                      logger.error("Required single-life Perl core module '#{dep_name}' comparator version convert failed, existing version template not found")
                      raise FPM::InvalidPackageConfiguration, "Requires single-life Perl core module '#{dep_name}' comparator version convert failed, existing version template not found"
                    end  # if, version template not found
                    v_version_converted = convert_version(v_version, perl_provides[dep_name])
                    if (v_version != v_version_converted)
                      logger.warn("Required single-life Perl core module '#{dep_name}' comparator version '#{v_comparator} #{v_version}' converted to '#{v_comparator} #{v_version_converted}'")
                      v_version = v_version_converted
                    end  # if, version converted
                  end  # if, distribution is not 'perl'
#                  self.dependencies << "#{name} #{v}"  # INCORRECT ORIGINAL, unconverted version may not match format of version on CPAN
                  self.dependencies << "#{name} #{v_comparator} #{v_version}"

                else  # version string does not include comparator, version number only
                  # DEV NOTE, CORRELATION #ctf10: convert all versions before creating package, except single-life Perl core modules in distribution 'perl'; deps/requires
                  v = v.to_s
                  if (dep_distribution != 'perl')
                    v_converted = convert_version(v, '')
                    if (v != v_converted)
                      logger.warn("Required module '#{dep_name}' non-comparator version '#{v}' converted to '#{v_converted}'")
                      v = v_converted
                    end  # if, version converted
                  else
                    # DEV NOTE, CORRELATION #ctf11: deps/requires which are single-life Perl core packages must conform to existing repo version formats
                    puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', in versions loop, non-comparator version dep is SINGLE-LIFE PERL CORE MODULE, need convert"
                    if (not perl_provides.key?(dep_name))
                      logger.error("Required single-life Perl core module '#{dep_name}' non-comparator version convert failed, existing version template not found")
                      raise FPM::InvalidPackageConfiguration, "Requires single-life Perl core module '#{dep_name}' non-comparator version convert failed, existing version template not found"
                    end  # if, version template not found
                    v_converted = convert_version(v, perl_provides[dep_name])
                    if (v != v_converted)
                      logger.warn("Required single-life Perl core module '#{dep_name}' non-comparator version '#{v}' converted to '#{v_converted}'")
                      v = v_converted
                    end  # if, version converted
                  end  # if, distribution is not 'perl'
                  self.dependencies << "#{name} >= #{v}"

                end  # if, version string includes comparator
              end  # loop, individual version strings

            else  # version is numeric only
              # DEV NOTE, CORRELATION #ctf10: convert all versions before creating package, except single-life Perl core modules in distribution 'perl'; deps/requires
              version = version.to_s
              if (dep_distribution != 'perl')
                version_converted = convert_version(version, '')
                if (version != version_converted)
                  logger.warn("Required module '#{dep_name}' numeric version '#{version.to_s}' converted to '#{version_converted}'")
                   version = version_converted
                end  # if, version converted
              else
                # DEV NOTE, CORRELATION #ctf11: deps/requires which are single-life Perl core packages must conform to existing repo version formats
                puts "[[[ DEBUG ]]] in cpan::input(), in deps/requires loop for dep_name = '#{dep_name}', in versions loop, numeric version dep is SINGLE-LIFE PERL CORE MODULE, need convert"
                if (not perl_provides.key?(dep_name))
                  logger.error("Required single-life Perl core module '#{dep_name}' numeric version convert failed, existing version template not found")
                  raise FPM::InvalidPackageConfiguration, "Requires single-life Perl core module '#{dep_name}' numeric version convert failed, existing version template not found"
                end  # if, version template not found
                version_converted = convert_version(version, perl_provides[dep_name])
                if (version != version_converted)
                  logger.warn("Required single-life Perl core module '#{dep_name}' numeric version '#{version.to_s}' converted to '#{version_converted}'")
                  version = version_converted
                end  # if, version converted
              end  # if, distribution is not 'perl'
              self.dependencies << "#{name} >= #{version}"

            end  # if, version is string or numeric
          end  # if, version is '= 0'
        end  # loop, individual dependencies
      end  # if, has dependencies
    end #no_auto_depends

# [[[ END MODIFIED CODE ]]]

    ::Dir.chdir(moduledir) do
      # TODO(sissel): install build and config dependencies to resolve
      # build/configure requirements.
      # META.yml calls it 'configure_requires' and 'build_requires'
      # META.json calls it prereqs/build and prereqs/configure

#      prefix = attributes[:prefix] || "/usr/local"  # incorrect original, must not force install to "/usr/local/..." directories
      prefix = attributes[:prefix] || ""

      # Try Makefile.PL, Build.PL
      #
      if File.exist?("Build.PL")
        # Module::Build is in use here; different actions required.
#        safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
        safesystemin("", attributes[:cpan_perl_bin],
                   "-Mlocal::lib=#{build_path("cpan")}",
                   "Build.PL",
                   # DEV NOTE, CORRELATION #ctf20: set default install path to "vendor" which will become the "vendor_perl/" directory, instead of the default "site_perl/"
                    "--installdirs vendor")
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
                     # DEV NOTE, CORRELATION #ctf20: set default install path to "vendor" which will become the "vendor_perl/" directory, instead of the default "site_perl/"
                     "INSTALLDIRS=vendor",
                     # Empty install_base to avoid local::lib being used.
                     "INSTALL_BASE=")
        else
#          safesystem(attributes[:cpan_perl_bin],  # hangs on interactive build, waiting for user input
          safesystemin("", attributes[:cpan_perl_bin],
                     "-Mlocal::lib=#{build_path("cpan")}",
                     "Makefile.PL", "PREFIX=#{prefix}",
                     # DEV NOTE, CORRELATION #ctf20: set default install path to "vendor" which will become the "vendor_perl/" directory, instead of the default "site_perl/"
                     "INSTALLDIRS=vendor",
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


  def convert_version(version, version_template)
    puts '[[[ DEBUG ]]] in convert_version(), received version = ' + version
    puts '[[[ DEBUG ]]] in convert_version(), received version_template = ' + version_template

    # all versions must be stringified, both dotted-decimal and floating-point
    if (not version.kind_of?(String))
      version = version.to_s
    end

    version_type = ''

    if (version[0] == 'v')  
      version_type = 'dotted_decimal'
      # strip all leading 'v' characters
      version[0] = ''
    elsif (version.count('.') > 1)
      version_type = 'dotted_decimal'
    elsif (version.count('.') == 1)
      version_type = 'floating_point'
    else
      version_type = 'integer'
    end

    puts '[[[ DEBUG ]]] in convert_version(), have version_type = ' + version_type

    version_converted = ''

    if (version_type == 'dotted_decimal')
      # no need to convert if already dotted-decimal
      puts '[[[ DEBUG ]]] in convert_version(), DO NOT CONVERT VERSION, already dotted-decimal'
      version_converted = version
    elsif (version_type == 'floating_point')
      if (version_template == '')
        puts '[[[ DEBUG ]]] in convert_version(), CONVERT VERSION, is floating-point'
        version_converted = floatstring_to_dottedstring(version)
      else
        puts '[[[ DEBUG ]]] in convert_version(), CONVERT VERSION, is floating-point w/ template'
        version_converted = floatstring_to_dottedstring_template(version, version_template)
      end
    elsif (version_type == 'integer')
      puts '[[[ DEBUG ]]] in convert_version(), DO NOT CONVERT VERSION, is integer'
      version_converted = version
    else  # invalid version_type
      logger.error("Converting version failed, invalid version_type = '#{version_type}'")
      raise FPM::InvalidPackageConfiguration, "Converting version failed, invalid version_type"
    end  # if, version_type

    puts '[[[ DEBUG ]]] in convert_version(), about to return version_converted = ' + version_converted

    return version_converted
  end  # subroutine, convert_version()


  def run_repoquery_provides(package)
    puts '[[[ DEBUG ]]] in run_repoquery_provides(), received package = ' + package

    execute_command = ''
    stdout_generated = ''
    stderr_generated = ''
    exit_status = nil

    # [[[ DETERMINE EXECUTION COMMAND ]]]

    # HARD-CODED EXAMPLE:
    # repoquery --provides perl-IO-Compress
    execute_command = 'repoquery --provides ' + package

    puts '[[[ DEBUG ]]] in run_repoquery_provides(), have execute_command = ' + execute_command

    # [[[ EXECUTE COMMAND ]]]

    require 'open3'

    Open3.popen3(execute_command) do |stdin, stdout_pipe, stderr_pipe, thread|
#      pid = thread.pid
      stdout_generated = stdout_pipe.read.chomp
      stderr_generated = stderr_pipe.read.chomp
      exit_status = thread.value  # Process::Status object returned
    end

    if (not exit_status.exited?)
      logger.error("repoquery provides failed, exit status false")
      raise FPM::InvalidPackageConfiguration, "repoquery provides failed, exit status false"
    elsif (stderr_generated != '')
      logger.error("repoquery provides failed, stdout not empty", :error => stderr_generated)
      raise FPM::InvalidPackageConfiguration, "repoquery provides failed, stdout not empty"
    end

    puts '[[[ DEBUG ]]] in run_repoquery_provides(), have stdout_generated = ' + "\n" + stdout_generated

    # [[[ PARSE COMMAND OUTPUT ]]]

    provides = {}
    package_current = ''
    epoch_current = ''
    version_current = ''

# HARD-CODED EXAMPLE
# perl = 4:5.16.3-292.el7
# perl(:MODULE_COMPAT_5.16.0)
# perl(:MODULE_COMPAT_5.16.1)
# ...
# perl(B::Deparse) = 1.14
# perl(B::OBJECT)
# ...
# perl(warnings) = 1.13
# perl(warnings::register) = 1.02
# perl(x86-64) = 4:5.16.3-292.el7

    stdout_generated.each_line do |stdout_generated_line|
      if (stdout_generated_line =~ /^perl\((.+)\)\s=\s(\d+:)?(.+)$/)
        package_current = $1
#        epoch_current = $2  # epoch currently unused
        version_current = $3
        provides[package_current] = version_current
        package_current = ''
#        epoch_current = ''
        version_current = ''
      end  # if, single line regex
    end  # do loop, multiple line stdout_generated

    return provides
  end


=begin DISABLED, unused code
  def run_yum_query(module_or_distribution, is_module_or_distribution)
    puts '[[[ DEBUG ]]] in run_yum_query(), received module_or_distribution = ' + module_or_distribution
    puts '[[[ DEBUG ]]] in run_yum_query(), received is_module_or_distribution = ' + is_module_or_distribution

    execute_command = ''
    stdout_generated = ''
    stderr_generated = ''
    exit_status = nil

    # [[[ DETERMINE EXECUTION COMMAND ]]]

    # distribution
    if (module_or_distribution[0..4] == 'perl-')
      if (is_module_or_distribution != 'distribution')
        logger.error("yum provides query failed, received 'perl-' distribution marked as non-distribution", :module_or_distribution => module_or_distribution)
        raise FPM::InvalidPackageConfiguration, "yum provides query failed, received 'perl-' distribution marked as non-distribution"
      end
      # HARD-CODED EXAMPLE:
      # yum -q provides 'perl-Foo-Bar'
      execute_command = 'yum -q provides ' + %q{'} + module_or_distribution + %q{'}
    elsif (module_or_distribution =~ /-/)
      if (is_module_or_distribution != 'distribution')
        logger.error("yum provides query failed, received '-' distribution marked as non-distribution", :module_or_distribution => module_or_distribution)
        raise FPM::InvalidPackageConfiguration, "yum provides query failed, received '-' distribution marked as non-distribution"
      end
      # HARD-CODED EXAMPLE:
      # yum -q provides 'perl-Foo-Bar'
      execute_command = 'yum -q provides ' + %q{'perl-} + module_or_distribution + %q{'}
    elsif (is_module_or_distribution == 'distribution')
      # HARD-CODED EXAMPLE:
      # yum -q provides 'perl-BSON'
      execute_command = 'yum -q provides ' + %q{'perl-} + module_or_distribution + %q{'}

    # module
    elsif (module_or_distribution =~ /::/)
      if (is_module_or_distribution != 'module')
        logger.error("yum provides query failed, received '::' module marked as non-module", :module_or_distribution => module_or_distribution)
        raise FPM::InvalidPackageConfiguration, "yum provides query failed, received '::' module marked as non-module"
      end
      # HARD-CODED EXAMPLE:
      # yum -q provides 'perl(IO::Compress)'
      execute_command = 'yum -q provides ' + %q{'perl(} + module_or_distribution + %q{)'}
    else
      # HARD-CODED EXAMPLE:
      # yum -q provides 'perl(Foo)'
      execute_command = 'yum -q provides ' + %q{'perl(} + module_or_distribution + %q{)'}
    end

    puts '[[[ DEBUG ]]] in run_yum_query(), have execute_command = ' + execute_command

    # [[[ EXECUTE COMMAND ]]]

    require 'open3'

    Open3.popen3(execute_command) do |stdin, stdout_pipe, stderr_pipe, thread|
#      pid = thread.pid
      stdout_generated = stdout_pipe.read.chomp
      stderr_generated = stderr_pipe.read.chomp
      exit_status = thread.value  # Process::Status object returned
    end

    if (not exit_status.exited?)
      logger.error("yum provides query failed, exit status false")
      raise FPM::InvalidPackageConfiguration, "yum provides query failed, exit status false"
    elsif (stderr_generated != '')
      logger.error("yum provides query failed, stdout not empty", :error => stderr_generated)
      raise FPM::InvalidPackageConfiguration, "yum provides query failed, stdout not empty"
    end

    puts '[[[ DEBUG ]]] in run_yum_query(), have stdout_generated = ' + "\n" + stdout_generated

    # [[[ PARSE COMMAND OUTPUT ]]]

    repos = {}
    repo_current = ''
    epoch_current = ''
    version_current = ''

    if (is_module_or_distribution == 'distribution')

# HARD-CODED EXAMPLE
#perl-ExtUtils-MakeMaker-6.68-3.el7.noarch : Create a module Makefile
#Repo        : base
#  [[[ 3 BLANK LINES ]]]
#10:perl-ExtUtils-MakeMaker-7.34-1.noarch : Create a module Makefile
#Repo        : centos7-perl-cpan
#  [[[ 3 BLANK LINES ]]]
#perl-ExtUtils-MakeMaker-6.68-3.el7.noarch : Create a module Makefile
#Repo        : @base

# HARD-CODED EXAMPLE
#10:perl-Text-Tabs+Wrap-2013.0523-1.noarch : Expand tabs and do simple line
#                                          : wrapping
#Repo        : centos7-perl-cpan

      stdout_generated.each_line do |stdout_generated_line|
        if (stdout_generated_line =~ /^(\d+:)?perl-#{Regexp.quote(module_or_distribution)}-(v?[\d.]+)-[\w.]+\s:/)
#        if (stdout_generated_line =~ /^(\d+:)?perl-#{module_or_distribution}-(v?[\d.]+)-[\w.]+\s:/)  # does not handle special characters such as '+' in 'Text-Tabs+Wrap'
          epoch_current = $1
          version_current = $2
        elsif (stdout_generated_line =~ /^Repo\s+:\s([\w.@-]+)/)
          if (version_current == '')
            logger.error("yum provides query failed, did not properly parse output for version before repo", :module_or_distribution => module_or_distribution)
            raise FPM::InvalidPackageConfiguration, "yum provides query failed, did not properly parse output for version before repo"
          end
          repo_current = $1
          repos[repo_current] = version_current
          repo_current = ''
          epoch_current = ''
          version_current = ''
        end  # if, single line regex
      end  # do loop, multiple line stdout_generated

    elsif (is_module_or_distribution == 'module')

      stdout_generated.each_line do |stdout_generated_line|
        if (stdout_generated_line =~ /^Repo\s+:\s([\w.@-]+)/)
          repo_current = $1
        elsif (stdout_generated_line =~ /^Provides\s+:\sperl\([\w:]+\)\s=\s(v?[\d.]+)/)
          if (repo_current == '')
            logger.error("yum provides query failed, did not properly parse output for repo before version", :module_or_distribution => module_or_distribution)
            raise FPM::InvalidPackageConfiguration, "yum provides query failed, did not properly parse output for repo before version"
          end
          version_current = $1
          repos[repo_current] = version_current
          repo_current = ''
          version_current = ''
        end  # if, single line regex
      end  # do loop, multiple line stdout_generated

    else
      logger.error("yum provides query failed, did not properly determine module or distribution", :module_or_distribution => module_or_distribution)
      raise FPM::InvalidPackageConfiguration, "yum provides query failed, did not properly determine module or distribution"
    end  # if, module or distribution

    return repos

  end

  # WBRASWELL 20180912 2018.255: convert dotted-decimal strings to floating-point strings for proper package dependency checking
  def dottedstring_to_floatstring(input_dottedstring)
    puts '[[[ DEBUG ]]] in dottedstring_to_floatstring(), received input_dottedstring = ' + input_dottedstring

    # strip leading v_prefix if present
    if (input_dottedstring[0] == 'v')
      input_dottedstring[0] = ''
    end

    # split dotted-decimal components based on dot '.' character
    input_dottedstring_components = input_dottedstring.split('.')
    puts '[[[ DEBUG ]]] in dottedstring_to_floatstring(), have input_dottedstring_components = '
    pp input_dottedstring_components

    is_first_component = 1
    output_floatstring = ''

    # loop through all dotted-decimal components
    input_dottedstring_components.each do |input_dottedstring_component|
      puts '[[[ DEBUG ]]] in dottedstring_to_floatstring(), top of loop, have input_dottedstring_component = ' + input_dottedstring_component
      # only one dot '.' character in output floating-point string
      if (is_first_component == 1)
        output_floatstring = input_dottedstring_component + '.'
        is_first_component = 0

      # after dot '.' character, pad components with zero '0' characters for at least 3 significant digits per component
      else
        # segments with more than 3 digits can not be converted
        if (input_dottedstring_component.length > 3)
          logger.error("converting version from dotted-decimal to floating-point failed, segment has more than 3 digits", 
            :input_dottedstring_component => input_dottedstring_component)
          raise FPM::InvalidPackageConfiguration, "converting version from dotted-decimal to floating-point failed, segment has more than 3 digits"
        end

        # pad with zero '0' characters
        input_dottedstring_component = '000' + input_dottedstring_component

        # truncate extraneous zero '0' characters, should always be at least 1 extra zero '0' with 3 zero '0' characters '000' prepended above
        input_dottedstring_component = input_dottedstring_component.reverse[0, 3].reverse

        # no more dot '.' characters after the first component
        output_floatstring += input_dottedstring_component
      end  # if, is_first_component
    end  # do loop
    
    puts '[[[ DEBUG ]]] in dottedstring_to_floatstring(), about to return output_floatstring = ' + output_floatstring
    return output_floatstring
  end
=end


  # WBRASWELL 20180921 2018.264: convert floating-point string to dotted-decimal string
  def floatstring_to_dottedstring(input_floatstring)
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring(), received input_floatstring = ' + input_floatstring

    # delete all underscore '_' characters, sometimes they mean pre-release alpha/beta software, sometimes they don't, always ignore
    if (input_floatstring.count('_') > 0)
      input_floatstring = input_floatstring.gsub('_', '')
      puts '[[[ DEBUG ]]] in floatstring_to_dottedstring(), stripped underscores, modified input_floatstring = ' + input_floatstring
    end

    # split floating-point components based on dot '.' character
    input_floatstring_components = input_floatstring.split('.')
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring(), have input_floatstring_components = '
    pp input_floatstring_components

    # truncate first component of floating-point input, because it is directly copied below
    input_floatstring_truncated = input_floatstring_components[1]

    # do not split the digits of the integer component (left of decimal point) of the floating-point input string, copy digits directly
    output_dottedstring = input_floatstring_components[0]

    triplet_index = 0

    # iterate through all characters after decimal
    for floatstring_index in 0..(input_floatstring_truncated.length - 1) do

      # copy 3 characters per dot-delimited component
      if ((triplet_index % 3) == 0)
        output_dottedstring += '.'
        triplet_index = 0
      end  # if, triplet_index
      triplet_index += 1
      output_dottedstring += input_floatstring_truncated[floatstring_index]
    end  # for, dottedstring_index

    # normalize all components to exactly 3 digits by padding-on-right with '0' characters,
    # this forces self-compatibility with all other packages created by FPM, which is the best we can hope for
    output_dottedstring += ('0' * (3 - triplet_index))

    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring(), about to return output_dottedstring = ' + output_dottedstring
    return output_dottedstring
  end


  # WBRASWELL 20180922 2018.265: convert floating-point string to dotted-decimal string, using pre-existing version as template
  def floatstring_to_dottedstring_template(input_floatstring, input_dottedstring)
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), received input_floatstring = ' + input_floatstring
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), received input_dottedstring = ' + input_dottedstring

    # delete all underscore '_' characters, sometimes they mean pre-release alpha/beta software, sometimes they don't, always ignore
    if (input_floatstring.count('_') > 0)
      input_floatstring = input_floatstring.gsub('_', '')
      puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), stripped underscores, modified input_floatstring = ' + input_floatstring
    end
    if (input_dottedstring.count('_') > 0)
      input_dottedstring = input_dottedstring.gsub('_', '')
      puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), stripped underscores, modified input_dottedstring = ' + input_dottedstring
    end

    # split floating-point components based on dot '.' character
    input_floatstring_components = input_floatstring.split('.')
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), have input_floatstring_components = '
    pp input_floatstring_components
    input_dottedstring_components = input_dottedstring.split('.')
    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), have input_dottedstring_components = '
    pp input_dottedstring_components

    # truncate first component of floating-point input, because it is directly copied below
    input_floatstring_truncated = input_floatstring_components[1]
    puts "[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), have input_floatstring_truncated = '#{input_floatstring_truncated}'"

    # truncate first component of dotted-decimal input, because it is not used
    input_dottedstring_truncated = input_dottedstring_components[1..-1].join('.')
    puts "[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), have input_dottedstring_truncated = '#{input_dottedstring_truncated}'"

    # do not split the digits of the integer component (left of decimal point) of the floating-point input string, copy digits directly & append the first dot '.' character
    output_dottedstring = input_floatstring_components[0] + '.'

    # track indices separately
    floatstring_index = 0

    # iterate through all characters after decimal
    for dottedstring_index in 0..(input_dottedstring_truncated.length - 1) do
      if (input_dottedstring_truncated[dottedstring_index] == '.')
        output_dottedstring += '.'
      else
        if (floatstring_index < input_floatstring_truncated.length)
          output_dottedstring += input_floatstring_truncated[floatstring_index]
          floatstring_index += 1
        else
          # if floatstring has too few characters, must pad on right with additional zero '0' characters, in order to match significant digits for proper version comparisions
          output_dottedstring += '0'
        end  # if, reached end of input_floatstring_truncated
      end  # if, input_dottedstring character is dot '.'
    end  # for, dottedstring_index

    # append any remaining floating-point digits as a separate dotted-decimal component, in order to match significant digits for proper version comparisions
    if (floatstring_index < input_floatstring_truncated.length)
      output_dottedstring += '.' + input_floatstring_truncated[floatstring_index..-1]
    end

    puts '[[[ DEBUG ]]] in floatstring_to_dottedstring_template(), about to return output_dottedstring = ' + output_dottedstring
    return output_dottedstring
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
