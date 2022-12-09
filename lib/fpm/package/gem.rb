require "fpm/namespace"
require "fpm/package"
require "rubygems"
require "fileutils"
require "fpm/util"
require "yaml"

# A rubygems package.
#
# This does not currently support 'output'
#
# The following attributes are supported:
#
# * :gem_bin_path
# * :gem_package_name_prefix
# * :gem_gem
class FPM::Package::Gem < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:gem_foo]
  option "--bin-path", "DIRECTORY", "The directory to install gem executables"
  option "--package-prefix", "NAMEPREFIX",
    "(DEPRECATED, use --package-name-prefix) Name to prefix the package " \
    "name with." do |value|
    logger = Cabin::Channel.get
    logger.warn("Using deprecated flag: --package-prefix. Please use " \
                 "--package-name-prefix")
    value
  end
  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "rubygem"
  option "--gem", "PATH_TO_GEM",
          "The path to the 'gem' tool (defaults to 'gem' and searches " \
          "your $PATH)", :default => "gem"
  option "--shebang", "SHEBANG",
          "Replace the shebang in the executables in the bin path with a " \
          "custom string", :default => nil
  option "--fix-name", :flag, "Should the target package name be prefixed?",
    :default => true
  option "--fix-dependencies", :flag, "Should the package dependencies be " \
    "prefixed?", :default => true
  option "--env-shebang", :flag, "Should the target package have the " \
    "shebang rewritten to use env?", :default => true

  option "--prerelease", :flag, "Allow prerelease versions of a gem", :default => false
  option "--disable-dependency", "gem_name",
    "The gem name to remove from dependency list",
    :multivalued => true, :attribute_name => :gem_disable_dependencies
  option "--embed-dependencies", :flag, "Should the gem dependencies " \
    "be installed?", :default => false

  option "--version-bins", :flag, "Append the version to the bins", :default => false

  option "--stagingdir", "STAGINGDIR",
    "The directory where fpm installs the gem temporarily before conversion. " \
    "Normally a random subdirectory of workdir."

  option "--git-repo", "GIT_REPO",
    "Use this git repo address as the source of the gem instead of " \
    "rubygems.org.", :default => nil

  option "--git-branch", "GIT_BRANCH",
    "When using a git repo as the source of the gem instead of " \
    "rubygems.org, use this git branch.",
    :default => nil

  # Override parent method
  def staging_path(path=nil)
    @gem_staging_path ||= attributes[:gem_stagingdir] || Stud::Temporary.directory("package-#{type}-staging")
    @staging_path = @gem_staging_path

    if path.nil?
      return @staging_path
    else
      return File.join(@staging_path, path)
    end
  end # def staging_path

  def input(gem)
    # 'arg'  is the name of the rubygem we should unpack.
    path_to_gem = download_if_necessary(gem, version)

    # Got a good gem now (downloaded or otherwise)
    #
    # 1. unpack it into staging_path
    # 2. take the metadata from it and update our wonderful package with it.
    load_package_info(path_to_gem)
    install_to_staging(path_to_gem)
  end # def input

  def download_if_necessary(gem, gem_version)
    path = gem
    if !File.exist?(path)
      path = download(gem, gem_version)
    end

    logger.info("Using gem file", :path => path)
    return path
  end # def download_if_necessary

  def download(gem_name, gem_version=nil)

    logger.info("Trying to download", :gem => gem_name, :version => gem_version)

    download_dir = build_path(gem_name)
    FileUtils.mkdir(download_dir) unless File.directory?(download_dir)

    if attributes[:gem_git_repo]
      logger.debug("Git cloning in directory #{download_dir}")
      safesystem("git", "-C", download_dir, "clone", attributes[:gem_git_repo], ".")
      if attributes[:gem_git_branch]
        safesystem("git", "-C", download_dir, "checkout", attributes[:gem_git_branch])
      end

      gem_build = [ "#{attributes[:gem_gem]}", "build", "#{download_dir}/#{gem_name}.gemspec"]
      ::Dir.chdir(download_dir) do |dir|
        logger.debug("Building in directory #{dir}")
        safesystem(*gem_build)
      end
      gem_files = ::Dir.glob(File.join(download_dir, "*.gem"))
    else
      gem_fetch = [ "#{attributes[:gem_gem]}", "fetch", gem_name]
      gem_fetch += ["--prerelease"] if attributes[:gem_prerelease?]
      gem_fetch += ["--version", gem_version] if gem_version
      ::Dir.chdir(download_dir) do |dir|
        logger.debug("Downloading in directory #{dir}")
        safesystem(*gem_fetch)
      end
      gem_files = ::Dir.glob(File.join(download_dir, "*.gem"))
    end

    if gem_files.length != 1
      raise "Unexpected number of gem files in #{download_dir},  #{gem_files.length} should be 1"
    end

    return gem_files.first
  end # def download

  GEMSPEC_YAML_CLASSES = [ ::Gem::Specification, ::Gem::Version, Time, ::Gem::Dependency, ::Gem::Requirement, Symbol ]
  def load_package_info(gem_path)
    # TODO(sissel): Maybe we should check if `safe_load` method exists instead of this version check?
    if ::Gem::Version.new(RUBY_VERSION) >= ::Gem::Version.new("3.1.0")
      # Ruby 3.1.0 switched to a Psych/YAML version that defaults to "safe" loading
      # and unfortunately `gem specification --yaml` emits YAML that requires
      # class loaders to process correctly
      spec = YAML.load(%x{#{attributes[:gem_gem]} specification #{gem_path} --yaml},
                      :permitted_classes => GEMSPEC_YAML_CLASSES)
    else
      # Older versions of ruby call this method YAML.safe_load
      spec = YAML.safe_load(%x{#{attributes[:gem_gem]} specification #{gem_path} --yaml}, GEMSPEC_YAML_CLASSES)
    end

    if !attributes[:gem_package_prefix].nil?
      attributes[:gem_package_name_prefix] = attributes[:gem_package_prefix]
    end

    # name prefixing is optional, if enabled, a name 'foo' will become
    # 'rubygem-foo' (depending on what the gem_package_name_prefix is)
    self.name = spec.name
    if attributes[:gem_fix_name?]
      self.name = fix_name(spec.name)
    end

    #self.name = [attributes[:gem_package_name_prefix], spec.name].join("-")
    self.license = (spec.license or "no license listed in #{File.basename(gem_path)}")

    # expand spec's version to match RationalVersioningPolicy to prevent cases
    # where missing 'build' number prevents correct dependency resolution by target
    # package manager. Ie. for dpkg 1.1 != 1.1.0
    m = spec.version.to_s.scan(/(\d+)\.?/)
    self.version = m.flatten.fill('0', m.length..2).join('.')

    self.vendor = spec.author
    self.url = spec.homepage
    self.category = "Languages/Development/Ruby"

    # if the gemspec has C extensions defined, then this should be a 'native' arch.
    if !spec.extensions.empty?
      self.architecture = "native"
    else
      self.architecture = "all"
    end

    # make sure we have a description
    description_options = [ spec.description, spec.summary, "#{spec.name} - no description given" ]
    self.description = description_options.find { |d| !(d.nil? or d.strip.empty?) }

    # Upstream rpms seem to do this, might as well share.
    # TODO(sissel): Figure out how to hint this only to rpm?
    # maybe something like attributes[:rpm_provides] for rpm specific stuff?
    # Or just ignore it all together.
    #self.provides << "rubygem(#{self.name})"

    # By default, we'll usually automatically provide this, but in the case that we are
    # composing multiple packages, it's best to explicitly include it in the provides list.
    self.provides << "#{self.name} = #{self.version}"

    if !attributes[:no_auto_depends?] && !attributes[:gem_embed_dependencies?]
      spec.runtime_dependencies.map do |dep|
        # rubygems 1.3.5 doesn't have 'Gem::Dependency#requirement'
        if dep.respond_to?(:requirement)
          reqs = dep.requirement.to_s
        else
          reqs = dep.version_requirements
        end

        # Some reqs can be ">= a, < b" versions, let's handle that.
        reqs.to_s.split(/, */).each do |req|
          if attributes[:gem_disable_dependencies]
            next if attributes[:gem_disable_dependencies].include?(dep.name)
          end

          if attributes[:gem_fix_dependencies?]
            name = fix_name(dep.name)
          else
            name = dep.name
          end
          self.dependencies << "#{name} #{req}"
        end
      end # runtime_dependencies
    end #no_auto_depends
  end # def load_package_info

  def install_to_staging(gem_path)
    if attributes.include?(:prefix) && ! attributes[:prefix].nil?
      installdir = "#{staging_path}/#{attributes[:prefix]}"
    else
      gemdir = safesystemout(*[attributes[:gem_gem], 'env', 'gemdir']).chomp
      installdir = File.join(staging_path, gemdir)
    end

    ::FileUtils.mkdir_p(installdir)
    # TODO(sissel): Allow setting gem tool path
    args = [attributes[:gem_gem], "install", "--quiet", "--no-user-install", "--install-dir", installdir]
    if ::Gem::VERSION =~ /^[012]\./ 
      args += [ "--no-ri", "--no-rdoc" ]
    else
      # Rubygems 3.0.0 changed --no-ri to --no-document
      args += [ "--no-document" ]
    end

    if !attributes[:gem_embed_dependencies?]
      args += ["--ignore-dependencies"]
    end

    if attributes[:gem_env_shebang?]
      args += ["-E"]
    end

    if attributes.include?(:gem_bin_path) && ! attributes[:gem_bin_path].nil?
      bin_path = File.join(staging_path, attributes[:gem_bin_path])
    else
      gem_env  = safesystemout(*[attributes[:gem_gem], 'env']).split("\n")
      gem_bin  = gem_env.select{ |line| line =~ /EXECUTABLE DIRECTORY/ }.first.split(': ').last
      bin_path = File.join(staging_path, gem_bin)
    end

    args += ["--bindir", bin_path]
    ::FileUtils.mkdir_p(bin_path)
    args << gem_path
    safesystem(*args)

    # Replace the shebangs in the executables
    if attributes[:gem_shebang]
      ::Dir.entries(bin_path).each do |file_name|
        # exclude . and ..
        next if ['.', '..'].include?(file_name)
        # exclude everything which is not a file
        file_path = File.join(bin_path, file_name)
        next unless File.ftype(file_path) == 'file'
        # replace shebang in files if there is one
        file = File.read(file_path)
        if file.gsub!(/\A#!.*$/, "#!#{attributes[:gem_shebang]}")
          File.open(file_path, 'w'){|f| f << file}
        end
      end
    end

    # Delete bin_path if it's empty, and any empty parents (#612)
    # Above, we mkdir_p bin_path because rubygems aborts if the parent
    # directory doesn't exist, for example:
    #   ERROR:  While executing gem ... (Errno::ENOENT)
    #       No such file or directory - /tmp/something/weird/bin
    tmp = bin_path
    while ::Dir.entries(tmp).size == 2 || tmp == "/"  # just [ "..", "." ] is an empty directory
      logger.info("Deleting empty bin_path", :path => tmp)
      ::Dir.rmdir(tmp)
      tmp = File.dirname(tmp)
    end
    if attributes[:gem_version_bins?] and File.directory?(bin_path)
      (::Dir.entries(bin_path) - ['.','..']).each do |bin|
        FileUtils.mv("#{bin_path}/#{bin}", "#{bin_path}/#{bin}-#{self.version}")
      end
    end

    if attributes[:source_date_epoch_from_changelog?]
      detect_source_date_from_changelog(installdir)
    end

    # Remove generated Makefile and gem_make.out files, if any; they
    # are not needed, and may contain generated paths that cause
    # different output on successive runs.
    Find.find(installdir) do |path|
      if path =~ /.*(gem_make.out|Makefile|mkmf.log)$/
        logger.info("Removing no longer needed file %s to reduce nondeterminism" % path)
        File.unlink(path)
      end
    end

  end # def install_to_staging

  # Sanitize package name.
  # This prefixes the package name with 'rubygem' (but depends on the attribute
  # :gem_package_name_prefix
  def fix_name(name)
    return [attributes[:gem_package_name_prefix], name].join("-")
  end # def fix_name

  # Regular expression to accept a gem changelog line, and store date & version, if any, in named capture groups.
  # Supports formats suggested by http://keepachangelog.com and https://github.com/tech-angels/vandamme
  # as well as other similar formats that actually occur in the wild.
  # Build it in pieces for readability, and allow version and date in either order.
  # Whenever you change this, add a row to the test case in spec/fpm/package/gem_spec.rb.
  # Don't even try to handle dates that lack four-digit years.
  # Building blocks:
  P_RE_LEADIN    = '^[#=]{0,3}\s?'
  P_RE_VERSION_  = '[\w\.-]+\.[\w\.-]+[a-zA-Z0-9]'
  P_RE_SEPARATOR = '\s[-=/(]?\s?'
  P_RE_DATE1     = '\d{4}-\d{2}-\d{2}'
  P_RE_DATE2     = '\w+ \d{1,2}(?:st|nd|rd|th)?,\s\d{4}'
  P_RE_DATE3     = '\w+\s+\w+\s+\d{1,2},\s\d{4}'
  P_RE_DATE      = "(?<date>#{P_RE_DATE1}|#{P_RE_DATE2}|#{P_RE_DATE3})"
  P_RE_URL       = '\(https?:[-\w/.%]*\)'    # In parens, per markdown
  P_RE_GTMAGIC   = '\[\]'                    # github magic version diff, per chandler
  P_RE_VERSION   = "\\[?(?:Version |v)?(?<version>#{P_RE_VERSION_})\\]?(?:#{P_RE_URL}|#{P_RE_GTMAGIC})?"
  # The final RE's:
  P_RE_VERSION_DATE = "#{P_RE_LEADIN}#{P_RE_VERSION}#{P_RE_SEPARATOR}#{P_RE_DATE}"
  P_RE_DATE_VERSION = "#{P_RE_LEADIN}#{P_RE_DATE}#{P_RE_SEPARATOR}#{P_RE_VERSION}"

  # Detect release date, if found, store in attributes[:source_date_epoch]
  def detect_source_date_from_changelog(installdir)
    name = self.name.sub("rubygem-", "") + "-" + self.version
    changelog = nil
    datestr = nil
    r1 = Regexp.new(P_RE_VERSION_DATE)
    r2 = Regexp.new(P_RE_DATE_VERSION)

    # Changelog doesn't have a standard name, so check all common variations
    # Sort this list using LANG=C, i.e. caps first
    [
      "CHANGELIST",
      "CHANGELOG", "CHANGELOG.asciidoc", "CHANGELOG.md", "CHANGELOG.rdoc", "CHANGELOG.rst", "CHANGELOG.txt",
      "CHANGES",   "CHANGES.md",   "CHANGES.txt",
      "ChangeLog", "ChangeLog.md", "ChangeLog.txt",
      "Changelog", "Changelog.md", "Changelog.txt",
      "changelog", "changelog.md", "changelog.txt",
    ].each do |changelogname|
      path = File.join(installdir, "gems", name, changelogname)
      if File.exist?(path)
        changelog = path
        File.open path do |file|
          file.each_line do |line|
            if line =~ /#{self.version}/
              [r1, r2].each do |r|
                if r.match(line)
                  datestr = $~[:date]
                  break
                end
              end
            end
          end
        end
      end
    end
    if datestr
      date = Date.parse(datestr)
      sec = date.strftime("%s")
      attributes[:source_date_epoch] = sec
      logger.debug("Gem %s has changelog date %s, setting source_date_epoch to %s" % [name, datestr, sec])
    elsif changelog
      logger.debug("Gem %s changelog %s did not have recognizable date for release %s" % [name, changelog, self.version])
    else
      logger.debug("Gem %s did not have changelog with recognized name" % [name])
      # FIXME: check rubygems.org?
    end
  end # detect_source_date_from_changelog

  public(:input, :output)
end # class FPM::Package::Gem
