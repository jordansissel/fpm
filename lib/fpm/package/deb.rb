require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "backports/latest"
require "fileutils"
require "digest"
require "zlib"

# For handling conversion
require "fpm/package/cpan"
require "fpm/package/gem"

# Support for debian packages (.deb files)
#
# This class supports both input and output of packages.
class FPM::Package::Deb < FPM::Package

  # Map of what scripts are named.
  SCRIPT_MAP = {
    :before_install     => "preinst",
    :after_install      => "postinst",
    :before_remove      => "prerm",
    :after_remove       => "postrm",
    :after_purge        => "postrm",
  } unless defined?(SCRIPT_MAP)

  # The list of supported compression types. Default is gz (gzip)
  COMPRESSION_TYPES = [ "gz", "bzip2", "xz", "none" ]

  # https://www.debian.org/doc/debian-policy/ch-relationships.html#syntax-of-relationship-fields
  # Example value with version relationship: libc6 (>= 2.2.1)
  # Example value: libc6

  # Version string docs here: https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-version
  # The format is: [epoch:]upstream_version[-debian_revision].
  # epoch - This is a single (generally small) unsigned integer
  # upstream_version - must contain only alphanumerics 6 and the characters . + - ~
  # debian_revision - only alphanumerics and the characters + . ~
  RELATIONSHIP_FIELD_PATTERN = /^(?<name>[A-z0-9_-]+)(?: *\((?<relation>[<>=]+) *(?<version>(?:[0-9]+:)?[0-9A-Za-z+~.-]+(?:-[0-9A-Za-z+~.]+)?)\))?$/

  option "--ignore-iteration-in-dependencies", :flag,
            "For '=' (equal) dependencies, allow iterations on the specified " \
            "version. Default is to be specific. This option allows the same " \
            "version of a package but any iteration is permitted"

  option "--build-depends", "DEPENDENCY",
    "Add DEPENDENCY as a Build-Depends" do |dep|
    @build_depends ||= []
    @build_depends << dep
  end

  option "--pre-depends", "DEPENDENCY",
    "Add DEPENDENCY as a Pre-Depends" do |dep|
    @pre_depends ||= []
    @pre_depends << dep
  end

  option "--compression", "COMPRESSION", "The compression type to use, must " \
    "be one of #{COMPRESSION_TYPES.join(", ")}.", :default => "gz" do |value|
    if !COMPRESSION_TYPES.include?(value)
      raise ArgumentError, "deb compression value of '#{value}' is invalid. " \
        "Must be one of #{COMPRESSION_TYPES.join(", ")}"
    end
    value
  end

  option "--dist", "DIST-TAG", "Set the deb distribution.", :default => "unstable"

  # Take care about the case when we want custom control file but still use fpm ...
  option "--custom-control", "FILEPATH",
    "Custom version of the Debian control file." do |control|
    File.expand_path(control)
  end

  # Add custom debconf config file
  option "--config", "SCRIPTPATH",
    "Add SCRIPTPATH as debconf config file." do |config|
     File.expand_path(config)
  end

  # Add custom debconf templates file
  option "--templates", "FILEPATH",
    "Add FILEPATH as debconf templates file." do |templates|
    File.expand_path(templates)
  end

  option "--installed-size", "KILOBYTES",
    "The installed size, in kilobytes. If omitted, this will be calculated " \
    "automatically" do |value|
    value.to_i
  end

  option "--priority", "PRIORITY",
    "The debian package 'priority' value.", :default => "extra"

  option "--use-file-permissions", :flag,
    "Use existing file permissions when defining ownership and modes"

  option "--user", "USER", "The owner of files in this package", :default => 'root'

  option "--group", "GROUP", "The group owner of files in this package", :default => 'root'

  option "--changelog", "FILEPATH", "Add FILEPATH as debian changelog" do |file|
    File.expand_path(file)
  end

  option "--generate-changes", :flag,
    "Generate PACKAGENAME.changes file.",
    :default => false

  option "--upstream-changelog", "FILEPATH", "Add FILEPATH as upstream changelog" do |file|
    File.expand_path(file)
  end

  option "--recommends", "PACKAGE", "Add PACKAGE to Recommends" do |pkg|
    @recommends ||= []
    @recommends << pkg
    next @recommends
  end

  option "--suggests", "PACKAGE", "Add PACKAGE to Suggests" do |pkg|
    @suggests ||= []
    @suggests << pkg
    next @suggests
  end

  option "--meta-file", "FILEPATH", "Add FILEPATH to DEBIAN directory" do |file|
    @meta_files ||= []
    @meta_files << File.expand_path(file)
    next @meta_files
  end

  option "--interest", "EVENT", "Package is interested in EVENT trigger" do |event|
    @interested_triggers ||= []
    @interested_triggers << event
    next @interested_triggers
  end

  option "--activate", "EVENT", "Package activates EVENT trigger" do |event|
    @activated_triggers ||= []
    @activated_triggers << event
    next @activated_triggers
  end

  option "--interest-noawait", "EVENT", "Package is interested in EVENT trigger without awaiting" do |event|
    @interested_noawait_triggers ||= []
    @interested_noawait_triggers << event
    next @interested_noawait_triggers
  end

  option "--activate-noawait", "EVENT", "Package activates EVENT trigger" do |event|
    @activated_noawait_triggers ||= []
    @activated_noawait_triggers << event
    next @activated_noawait_triggers
  end

  option "--field", "'FIELD: VALUE'", "Add custom field to the control file" do |fv|
    @custom_fields ||= {}
    field, value = fv.split(/: */, 2)
    @custom_fields[field] = value
    next @custom_fields
  end

  option "--no-default-config-files", :flag,
    "Do not add all files in /etc as configuration files by default for Debian packages.",
    :default => false

  option "--auto-config-files", :flag,
    "Init script and default configuration files will be labeled as " \
    "configuration files for Debian packages.",
    :default => true

  option "--shlibs", "SHLIBS", "Include control/shlibs content. This flag " \
    "expects a string that is used as the contents of the shlibs file. " \
    "See the following url for a description of this file and its format: " \
    "http://www.debian.org/doc/debian-policy/ch-sharedlibs.html#s-shlibs"

  option "--init", "FILEPATH", "Add FILEPATH as an init script",
    :multivalued => true do |file|
    next File.expand_path(file)
  end

  option "--default", "FILEPATH", "Add FILEPATH as /etc/default configuration",
    :multivalued => true do |file|
    next File.expand_path(file)
  end

  option "--upstart", "FILEPATH", "Add FILEPATH as an upstart script",
    :multivalued => true do |file|
    next File.expand_path(file)
  end

  option "--systemd", "FILEPATH", "Add FILEPATH as a systemd script",
    :multivalued => true do |file|
    next File.expand_path(file)
  end

  option "--systemd-enable", :flag , "Enable service on install or upgrade", :default => false

  option "--systemd-auto-start", :flag , "Start service after install or upgrade", :default => false

  option "--systemd-restart-after-upgrade", :flag , "Restart service after upgrade", :default => true

  option "--after-purge", "FILE",
    "A script to be run after package removal to purge remaining (config) files " \
    "(a.k.a. postrm purge within apt-get purge)" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-purge

  option "--maintainerscripts-force-errorchecks", :flag ,
    "Activate errexit shell option according to lintian. " \
    "https://lintian.debian.org/tags/maintainer-script-ignores-errors.html",
    :default => false

  def initialize(*args)
    super(*args)
    attributes[:deb_priority] = "extra"
  end # def initialize

  private

  # Return the architecture. This will default to native if not yet set.
  # It will also try to use dpkg and 'uname -m' to figure out what the
  # native 'architecture' value should be.
  def architecture
    if @architecture.nil? or @architecture == "native"
      # Default architecture should be 'native' which we'll need to ask the
      # system about.
      if program_in_path?("dpkg")
        @architecture = %x{dpkg --print-architecture 2> /dev/null}.chomp
        if $?.exitstatus != 0 or @architecture.empty?
          # if dpkg fails or emits nothing, revert back to uname -m
          @architecture = %x{uname -m}.chomp
        end
      else
        @architecture = %x{uname -m}.chomp
      end
    end

    case @architecture
    when "x86_64"
      # Debian calls x86_64 "amd64"
      @architecture = "amd64"
    when "aarch64"
      # Debian calls aarch64 "arm64"
      @architecture = "arm64"
    when "noarch"
      # Debian calls noarch "all"
      @architecture = "all"
    end
    return @architecture
  end # def architecture

  # Get the name of this package. See also FPM::Package#name
  #
  # This accessor actually modifies the name if it has some invalid or unwise
  # characters.
  def name
    if @name =~ /[A-Z]/
      logger.warn("Debian tools (dpkg/apt) don't do well with packages " \
        "that use capital letters in the name. In some cases it will " \
        "automatically downcase them, in others it will not. It is confusing." \
        " Best to not use any capital letters at all. I have downcased the " \
        "package name for you just to be safe.",
        :oldname => @name, :fixedname => @name.downcase)
      @name = @name.downcase
    end

    if @name.include?("_")
      logger.info("Debian package names cannot include underscores; " \
                   "automatically converting to dashes", :name => @name)
      @name = @name.gsub(/[_]/, "-")
    end

    if @name.include?(" ")
      logger.info("Debian package names cannot include spaces; " \
                   "automatically converting to dashes", :name => @name)
      @name = @name.gsub(/[ ]/, "-")
    end

    return @name
  end # def name

  def prefix
    return (attributes[:prefix] or "/")
  end # def prefix

  def input(input_path)
    extract_info(input_path)
    extract_files(input_path)
  end # def input

  def extract_info(package)
    compression = `#{ar_cmd[0]} t #{package}`.split("\n").grep(/control.tar/).first.split(".").last
    case compression
      when "gz"
        controltar = "control.tar.gz"
        compression = "-z"
      when "bzip2","bz2"
        controltar = "control.tar.bz2"
        compression = "-j"
      when "xz"
        controltar = "control.tar.xz"
        compression = "-J"
      when 'tar'
        controltar = "control.tar"
        compression = ""
      when nil
        raise FPM::InvalidPackageConfiguration, "Missing control.tar in deb source package #{package}"
      else
        raise FPM::InvalidPackageConfiguration,
          "Unknown compression type '#{compression}' for control.tar in deb source package #{package}"
    end

    build_path("control").tap do |path|
      FileUtils.mkdir(path) if !File.directory?(path)
      # unpack the control.tar.{,gz,bz2,xz} from the deb package into staging_path
      # Unpack the control tarball
      safesystem(ar_cmd[0] + " p #{package} #{controltar} | tar #{compression} -xf - -C #{path}")

      control = File.read(File.join(path, "control"))

      parse = lambda do |field|
        value = control[/^#{field.capitalize}: .*/]
        if value.nil?
          return nil
        else
          logger.info("deb field", field => value.split(": ", 2).last)
          return value.split(": ",2).last
        end
      end

      # Parse 'epoch:version-iteration' in the version string
      version_re = /^(?:([0-9]+):)?(.+?)(?:-(.*))?$/
      m = version_re.match(parse.call("Version"))
      if !m
        raise "Unsupported version string '#{parse.call("Version")}'"
      end
      self.epoch, self.version, self.iteration = m.captures

      self.architecture = parse.call("Architecture")
      self.category = parse.call("Section")
      self.license = parse.call("License") || self.license
      self.maintainer = parse.call("Maintainer")
      self.name = parse.call("Package")
      self.url = parse.call("Homepage")
      self.vendor = parse.call("Vendor") || self.vendor
      parse.call("Provides").tap do |provides_str|
        next if provides_str.nil?
        self.provides = provides_str.split(/\s*,\s*/)
      end

      # The description field is a special flower, parse it that way.
      # The description is the first line as a normal Description field, but also continues
      # on future lines indented by one space, until the end of the file. Blank
      # lines are marked as ' .'
      description = control[/^Description: .*/m].split(": ", 2).last
      self.description = description.gsub(/^ /, "").gsub(/^\.$/, "")

      #self.config_files = config_files

      self.dependencies += parse_depends(parse.call("Depends")) if !attributes[:no_auto_depends?]

      if File.file?(File.join(path, "preinst"))
        self.scripts[:before_install] = File.read(File.join(path, "preinst"))
      end
      if File.file?(File.join(path, "postinst"))
        self.scripts[:after_install] = File.read(File.join(path, "postinst"))
      end
      if File.file?(File.join(path, "prerm"))
        self.scripts[:before_remove] = File.read(File.join(path, "prerm"))
      end
      if File.file?(File.join(path, "postrm"))
        self.scripts[:after_remove] = File.read(File.join(path, "postrm"))
      end
      if File.file?(File.join(path, "conffiles"))
        self.config_files = File.read(File.join(path, "conffiles")).split("\n")
      end
    end
  end # def extract_info

  # Parse a 'depends' line from a debian control file.
  #
  # The expected input 'data' should be everything after the 'Depends: ' string
  #
  # Example:
  #
  #     parse_depends("foo (>= 3), bar (= 5), baz")
  def parse_depends(data)
    return [] if data.nil? or data.empty?
    # parse dependencies. Debian dependencies come in one of two forms:
    # * name
    # * name (op version)
    # They are all on one line, separated by ", "

    dep_re = /^([^ ]+)(?: \(([>=<]+) ([^)]+)\))?$/
    return data.split(/, */).collect do |dep|
      m = dep_re.match(dep)
      if m
        name, op, version = m.captures
        # deb uses ">>" and "<<" for greater and less than respectively.
        # fpm wants just ">" and "<"
        op = "<" if op == "<<"
        op = ">" if op == ">>"
        # this is the proper form of dependency
        "#{name} #{op} #{version}"
      else
        # Assume normal form dependency, "name op version".
        dep
      end
    end
  end # def parse_depends

  def extract_files(package)
    # Find out the compression type
    compression = `#{ar_cmd[0]} t #{package}`.split("\n").grep(/data.tar/).first.split(".").last
    case compression
      when "gz"
        datatar = "data.tar.gz"
        compression = "-z"
      when "bzip2","bz2"
        datatar = "data.tar.bz2"
        compression = "-j"
      when "xz"
        datatar = "data.tar.xz"
        compression = "-J"
      when 'tar'
        datatar = "data.tar"
        compression = ""
      when nil
        raise FPM::InvalidPackageConfiguration, "Missing data.tar in deb source package #{package}"
      else
        raise FPM::InvalidPackageConfiguration,
          "Unknown compression type '#{compression}' for data.tar in deb source package #{package}"
    end

    # unpack the data.tar.{gz,bz2,xz} from the deb package into staging_path
    safesystem(ar_cmd[0] + " p #{package} #{datatar} | tar #{compression} -xf - -C #{staging_path}")
  end # def extract_files

  def output(output_path)
    self.provides = self.provides.collect { |p| fix_provides(p) }

    self.provides.each do |provide|
      if !valid_provides_field?(provide)
        raise FPM::InvalidPackageConfiguration, "Found invalid Provides field values (#{provide.inspect}). This is not valid in a Debian package."
      end
    end
    output_check(output_path)
    # Abort if the target path already exists.

    # create 'debian-binary' file, required to make a valid debian package
    File.write(build_path("debian-binary"), "2.0\n")

    # If we are given --deb-shlibs but no --after-install script, we
    # should implicitly create a before/after scripts that run ldconfig
    if attributes[:deb_shlibs]
      if !script?(:after_install)
        logger.info("You gave --deb-shlibs but no --after-install, so " \
                     "I am adding an after-install script that runs " \
                     "ldconfig to update the system library cache")
        scripts[:after_install] = template("deb/ldconfig.sh.erb").result(binding)
      end
      if !script?(:after_remove)
        logger.info("You gave --deb-shlibs but no --after-remove, so " \
                     "I am adding an after-remove script that runs " \
                     "ldconfig to update the system library cache")
        scripts[:after_remove] = template("deb/ldconfig.sh.erb").result(binding)
      end
    end

    if attributes[:source_date_epoch].nil? and not attributes[:source_date_epoch_default].nil?
      attributes[:source_date_epoch] = attributes[:source_date_epoch_default]
    end
    if attributes[:source_date_epoch] == "0"
      logger.error("Alas, ruby's Zlib::GzipWriter does not support setting an mtime of zero.  Aborting.")
      raise "#{name}: source_date_epoch of 0 not supported."
    end
    if not attributes[:source_date_epoch].nil? and not ar_cmd_deterministic?
      logger.error("Alas, could not find an ar that can handle -D option. Try installing recent gnu binutils. Aborting.")
      raise "#{name}: ar is insufficient to support source_date_epoch."
    end
    if not attributes[:source_date_epoch].nil? and not tar_cmd_supports_sort_names_and_set_mtime?
      logger.error("Alas, could not find a tar that can set mtime and sort.  Try installing recent gnu tar. Aborting.")
      raise "#{name}: tar is insufficient to support source_date_epoch."
    end

    attributes[:deb_systemd] = []
    attributes.fetch(:deb_systemd_list, []).each do |systemd|
      name = File.basename(systemd, ".service")
      dest_systemd = staging_path("lib/systemd/system/#{name}.service")
      mkdir_p(File.dirname(dest_systemd))
      FileUtils.cp(systemd, dest_systemd)
      File.chmod(0644, dest_systemd)

      # add systemd service name to attribute
      attributes[:deb_systemd] << name
    end

    if script?(:before_upgrade) or script?(:after_upgrade) or attributes[:deb_systemd].any?
      puts "Adding action files"
      if script?(:before_install) or script?(:before_upgrade)
        scripts[:before_install] = template("deb/preinst_upgrade.sh.erb").result(binding)
      end
      if script?(:before_remove) or not attributes[:deb_systemd].empty?
        scripts[:before_remove] = template("deb/prerm_upgrade.sh.erb").result(binding)
      end
      if script?(:after_install) or script?(:after_upgrade) or attributes[:deb_systemd].any?
        scripts[:after_install] = template("deb/postinst_upgrade.sh.erb").result(binding)
      end
      if script?(:after_remove)
        scripts[:after_remove] = template("deb/postrm_upgrade.sh.erb").result(binding)
      end
      if script?(:after_purge)
        scripts[:after_purge] = template("deb/postrm_upgrade.sh.erb").result(binding)
      end
    end

    # There are two changelogs that may appear:
    #   - debian-specific changelog, which should be archived as changelog.Debian.gz
    #   - upstream changelog, which should be archived as changelog.gz
    # see https://www.debian.org/doc/debian-policy/ch-docs.html#s-changelogs

    # Write the changelog.Debian.gz file
    dest_changelog = File.join(staging_path, "usr/share/doc/#{name}/changelog.Debian.gz")
    mkdir_p(File.dirname(dest_changelog))
    File.new(dest_changelog, "wb", 0644).tap do |changelog|
      Zlib::GzipWriter.new(changelog, Zlib::BEST_COMPRESSION).tap do |changelog_gz|
        if not attributes[:source_date_epoch].nil?
          changelog_gz.mtime = attributes[:source_date_epoch].to_i
        end
        if attributes[:deb_changelog]
          logger.info("Writing user-specified changelog", :source => attributes[:deb_changelog])
          File.new(attributes[:deb_changelog]).tap do |fd|
            chunk = nil
            # Ruby 1.8.7 doesn't have IO#copy_stream
            changelog_gz.write(chunk) while chunk = fd.read(16384)
          end.close
        else
          logger.info("Creating boilerplate changelog file")
          changelog_gz.write(template("deb/changelog.erb").result(binding))
        end
      end.close
    end # No need to close, GzipWriter#close will close it.

    # Write the changelog.gz file (upstream changelog)
    dest_upstream_changelog = File.join(staging_path, "usr/share/doc/#{name}/changelog.gz")
    if attributes[:deb_upstream_changelog]
      File.new(dest_upstream_changelog, "wb", 0644).tap do |changelog|
        Zlib::GzipWriter.new(changelog, Zlib::BEST_COMPRESSION).tap do |changelog_gz|
            if not attributes[:source_date_epoch].nil?
              changelog_gz.mtime = attributes[:source_date_epoch].to_i
            end
            logger.info("Writing user-specified upstream changelog", :source => attributes[:deb_upstream_changelog])
            File.new(attributes[:deb_upstream_changelog]).tap do |fd|
              chunk = nil
              # Ruby 1.8.7 doesn't have IO#copy_stream
              changelog_gz.write(chunk) while chunk = fd.read(16384)
            end.close
        end.close
      end # No need to close, GzipWriter#close will close it.
    end

    if File.exists?(dest_changelog) and not File.exists?(dest_upstream_changelog)
      # see https://www.debian.org/doc/debian-policy/ch-docs.html#s-changelogs
      File.rename(dest_changelog, dest_upstream_changelog)
    end

    attributes.fetch(:deb_init_list, []).each do |init|
      name = File.basename(init, ".init")
      dest_init = File.join(staging_path, "etc/init.d/#{name}")
      mkdir_p(File.dirname(dest_init))
      FileUtils.cp init, dest_init
      File.chmod(0755, dest_init)
    end

    attributes.fetch(:deb_default_list, []).each do |default|
      name = File.basename(default, ".default")
      dest_default = File.join(staging_path, "etc/default/#{name}")
      mkdir_p(File.dirname(dest_default))
      FileUtils.cp default, dest_default
      File.chmod(0644, dest_default)
    end

    attributes.fetch(:deb_upstart_list, []).each do |upstart|
      name = File.basename(upstart, ".upstart")
      dest_init = staging_path("etc/init.d/#{name}")
      name = "#{name}.conf" if !(name =~ /\.conf$/)
      dest_upstart = staging_path("etc/init/#{name}")
      mkdir_p(File.dirname(dest_upstart))
      FileUtils.cp(upstart, dest_upstart)
      File.chmod(0644, dest_upstart)

      # Install an init.d shim that calls upstart
      mkdir_p(File.dirname(dest_init))
      FileUtils.ln_s("/lib/init/upstart-job", dest_init)
    end

    attributes.fetch(:deb_systemd_list, []).each do |systemd|
      name = File.basename(systemd, ".service")
      dest_systemd = staging_path("lib/systemd/system/#{name}.service")
      mkdir_p(File.dirname(dest_systemd))
      FileUtils.cp(systemd, dest_systemd)
      File.chmod(0644, dest_systemd)
    end

    write_control_tarball

    # Tar up the staging_path into data.tar.{compression type}
    case self.attributes[:deb_compression]
      when "gz", nil
        datatar = build_path("data.tar.gz")
        controltar = build_path("control.tar.gz")
        compression_flags = ["-z"]
      when "bzip2"
        datatar = build_path("data.tar.bz2")
        controltar = build_path("control.tar.gz")
        compression_flags = ["-j"]
      when "xz"
        datatar = build_path("data.tar.xz")
        controltar = build_path("control.tar.xz")
        compression_flags = ["-J"]
      when "none"
        datatar = build_path("data.tar")
        controltar = build_path("control.tar")
        compression_flags = []
      else
        raise FPM::InvalidPackageConfiguration,
          "Unknown compression type '#{self.attributes[:deb_compression]}'"
    end
    args = [ tar_cmd, "-C", staging_path ] + compression_flags + data_tar_flags + [ "-cf", datatar, "." ]
    if tar_cmd_supports_sort_names_and_set_mtime? and not attributes[:source_date_epoch].nil?
      # Use gnu tar options to force deterministic file order and timestamp
      args += ["--sort=name", ("--mtime=@%s" % attributes[:source_date_epoch])]
      # gnu tar obeys GZIP environment variable with options for gzip; -n = forget original filename and date
      args.unshift({"GZIP" => "-9n"})
    end
    safesystem(*args)

    # pack up the .deb, which is just an 'ar' archive with 3 files
    # the 'debian-binary' file has to be first
    File.expand_path(output_path).tap do |output_path|
      ::Dir.chdir(build_path) do
        safesystem(*ar_cmd, output_path, "debian-binary", controltar, datatar)
      end
    end

    # if a PACKAGENAME.changes file is to be created
    if self.attributes[:deb_generate_changes?]
      distribution = self.attributes[:deb_dist]

      # gather information about the files to distribute
      files = [ output_path ]
      changes_files = []
      files.each do |path|
        changes_files.push({
          :name => path,
          :size => File.size?(path),
          :md5sum => Digest::MD5.file(path).hexdigest,
          :sha1sum => Digest::SHA1.file(path).hexdigest,
          :sha256sum => Digest::SHA2.file(path).hexdigest,
        })
      end

      # write change infos to .changes file
      changes_path = File.basename(output_path, '.deb') + '.changes'
      changes_data = template("deb/deb.changes.erb").result(binding)
      File.write(changes_path, changes_data)
      logger.log("Created changes", :path => changes_path)
    end # if deb_generate_changes
  end # def output

  def converted_from(origin)
    self.dependencies = self.dependencies.collect do |dep|
      fix_dependency(dep)
    end.flatten
    self.provides = self.provides.collect do |provides|
      fix_provides(provides)
    end.flatten

    if origin == FPM::Package::CPAN
      # The fpm cpan code presents dependencies and provides fields as perl(ModuleName)
      # so we'll need to convert them to something debian supports.

      # Replace perl(ModuleName) > 1.0 with Debian-style perl-ModuleName (> 1.0)
      perldepfix = lambda do |dep|
        m = dep.match(/perl\((?<name>[A-Za-z0-9_:]+)\)\s*(?<op>.*$)/)
        if m.nil?
          # 'dep' syntax didn't look like 'perl(Name) > 1.0'
          dep
        else
          # Also replace '::' in the perl module name with '-'
          modulename = m["name"].gsub("::", "-")
         
          # Fix any upper-casing or other naming concerns Debian has about packages
          name = "#{attributes[:cpan_package_name_prefix]}-#{modulename}"

          if m["op"].empty?
            name
          else
            # 'dep' syntax was like this (version constraint): perl(Module) > 1.0
            "#{name} (#{m["op"]})"
          end
        end
      end

      rejects = [ "perl(vars)", "perl(warnings)", "perl(strict)", "perl(Config)" ]
      self.dependencies = self.dependencies.reject do |dep|
        # Reject non-module Perl dependencies like 'vars' and 'warnings'
        rejects.include?(dep)
      end.collect(&perldepfix).collect(&method(:fix_dependency))

      # Also fix the Provides field 'perl(ModuleName) = version' to be 'perl-modulename (= version)'
      self.provides = self.provides.collect(&perldepfix).collect(&method(:fix_provides))

    end # if origin == FPM::Packagin::CPAN

    if origin == FPM::Package::Deb
      changelog_path = staging_path("usr/share/doc/#{name}/changelog.Debian.gz")
      if File.exists?(changelog_path)
        logger.debug("Found a deb changelog file, using it.", :path => changelog_path)
        attributes[:deb_changelog] = build_path("deb_changelog")
        File.open(attributes[:deb_changelog], "w") do |deb_changelog|
          Zlib::GzipReader.open(changelog_path) do |gz|
            IO::copy_stream(gz, deb_changelog)
          end
        end
        File.unlink(changelog_path)
      end
    end

    if origin == FPM::Package::Deb
      changelog_path = staging_path("usr/share/doc/#{name}/changelog.gz")
      if File.exists?(changelog_path)
        logger.debug("Found an upstream changelog file, using it.", :path => changelog_path)
        attributes[:deb_upstream_changelog] = build_path("deb_upstream_changelog")
        File.open(attributes[:deb_upstream_changelog], "w") do |deb_upstream_changelog|
          Zlib::GzipReader.open(changelog_path) do |gz|
            IO::copy_stream(gz, deb_upstream_changelog)
          end
        end
        File.unlink(changelog_path)
      end
    end

    if origin == FPM::Package::Gem
      # fpm's gem input will have provides as "rubygem-name = version"
      # and we need to convert this to Debian-style "rubygem-name (= version)"
      self.provides = self.provides.collect do |provides|
        m = /^(#{attributes[:gem_package_name_prefix]})-([^\s]+)\s*=\s*(.*)$/.match(provides)
        if m
          "#{m[1]}-#{m[2]} (= #{m[3]})"
        else
          provides
        end
      end
    end
  end # def converted_from

  def debianize_op(op)
    # Operators in debian packaging are <<, <=, =, >= and >>
    # So any operator like < or > must be replaced
    {:< => "<<", :> => ">>"}[op.to_sym] or op
  end

  def fix_dependency(dep)
    # Deb dependencies are: NAME (OP VERSION), like "zsh (> 3.0)"
    # Convert anything that looks like 'NAME OP VERSION' to this format.
    if dep =~ /[\(,\|]/
      # Don't "fix" ones that could appear well formed already.
    else
      # Convert ones that appear to be 'name op version'
      name, op, version = dep.split(/ +/)
      if !version.nil?
        # Convert strings 'foo >= bar' to 'foo (>= bar)'
        dep = "#{name} (#{debianize_op(op)} #{version})"
      end
    end

    name_re = /^[^ \(]+/
    name = dep[name_re]
    if name =~ /[A-Z]/
      logger.warn("Downcasing dependency '#{name}' because deb packages " \
                   " don't work so good with uppercase names")
      dep = dep.gsub(name_re) { |n| n.downcase }
    end

    if dep.include?("_")
      logger.warn("Replacing dependency underscores with dashes in '#{dep}' because " \
                   "debs don't like underscores")
      dep = dep.gsub("_", "-")
    end

    # Convert gem ~> X.Y.Z to '>= X.Y.Z' and << X.Y+1.0
    if dep =~ /\(~>/
      name, version = dep.gsub(/[()~>]/, "").split(/ +/)[0..1]
      nextversion = version.split(".").collect { |v| v.to_i }
      l = nextversion.length
      if l > 1
        nextversion[l-2] += 1
        nextversion[l-1] = 0
      else
        # Single component versions ~> 1
        nextversion[l-1] += 1
      end
      nextversion = nextversion.join(".")
      return ["#{name} (>= #{version})", "#{name} (<< #{nextversion})"]
    elsif (m = dep.match(/(\S+)\s+\(!= (.+)\)/))
      # Move '!=' dependency specifications into 'Breaks'
      self.attributes[:deb_breaks] ||= []
      self.attributes[:deb_breaks] << dep.gsub(/!=/,"=")
      return []
    elsif (m = dep.match(/(\S+)\s+\(= (.+)\)/)) and
        self.attributes[:deb_ignore_iteration_in_dependencies?]
      # Convert 'foo (= x)' to 'foo (>= x)' and 'foo (<< x+1)'
      # but only when flag --ignore-iteration-in-dependencies is passed.
      name, version = m[1..2]
      nextversion = version.split('.').collect { |v| v.to_i }
      nextversion[-1] += 1
      nextversion = nextversion.join(".")
      return ["#{name} (>= #{version})", "#{name} (<< #{nextversion})"]
    elsif (m = dep.match(/(\S+)\s+\(> (.+)\)/))
      # Convert 'foo (> x) to 'foo (>> x)'
      name, version = m[1..2]
      return ["#{name} (>> #{version})"]
    else
      # otherwise the dep is probably fine
      return dep.rstrip
    end
  end # def fix_dependency

  def valid_provides_field?(text)
    m = RELATIONSHIP_FIELD_PATTERN.match(text)
    if m.nil?
      logger.error("Invalid relationship field for debian package: #{text}")
      return false
    end

    # Per Debian Policy manual, https://www.debian.org/doc/debian-policy/ch-relationships.html#syntax-of-relationship-fields
    # >> The relations allowed are <<, <=, =, >= and >> for strictly earlier, earlier or equal,
    # >> exactly equal, later or equal and strictly later, respectively. The exception is the
    # >> Provides field, for which only = is allowed
    if m["relation"] == "=" || m["relation"] == nil
      return true
    end
    return false
  end

  def valid_relationship_field?(text)
    m = RELATIONSHIP_FIELD_PATTERN.match(text)
    if m.nil?
      logger.error("Invalid relationship field for debian package: #{text}")
      return false
    end
    return true
  end

  def fix_provides(provides)
    name_re = /^[^ \(]+/
    name = provides[name_re]
    if name =~ /[A-Z]/
      logger.warn("Downcasing provides '#{name}' because deb packages " \
                   " don't work so good with uppercase names")
      provides = provides.gsub(name_re) { |n| n.downcase }
    end

    if provides.include?("_")
      logger.warn("Replacing 'provides' underscores with dashes in '#{provides}' because " \
                   "debs don't like underscores")
      provides = provides.gsub("_", "-")
    end

    if m = provides.match(/^([A-Za-z0-9_-]+)\s*=\s*(\d+.*$)/)
      logger.warn("Replacing 'provides' entry #{provides} with syntax 'name (= version)'")
      provides = "#{m[1]} (= #{m[2]})"
    end
    return provides.rstrip
  end

  def control_path(path=nil)
    @control_path ||= build_path("control")
    FileUtils.mkdir(@control_path) if !File.directory?(@control_path)

    if path.nil?
      return @control_path
    else
      return File.join(@control_path, path)
    end
  end # def control_path

  def write_control_tarball
    # Use custom Debian control file when given ...
    write_control # write the control file
    write_shlibs # write optional shlibs file
    write_scripts # write the maintainer scripts
    write_conffiles # write the conffiles
    write_debconf # write the debconf files
    write_meta_files # write additional meta files
    write_triggers # write trigger config to 'triggers' file
    write_md5sums # write the md5sums file

    # Tar up the staging_path into control.tar.{compression type}
    case self.attributes[:deb_compression]
      when "gz", "bzip2", nil
        controltar = "control.tar.gz"
        compression_flags = ["-z"]
      when "xz"
        controltar = "control.tar.xz"
        compression_flags = ["-J"]
      when "none"
        controltar = "control.tar"
        compression_flags = []
      else
        raise FPM::InvalidPackageConfiguration,
          "Unknown compression type '#{self.attributes[:deb_compression]}'"
    end

    # Make the control.tar.gz
    build_path(controltar).tap do |controltar|
      logger.info("Creating", :path => controltar, :from => control_path)

      args = [ tar_cmd, "-C", control_path ] + compression_flags + [ "-cf", controltar,
        "--owner=0", "--group=0", "--numeric-owner", "." ]
      if tar_cmd_supports_sort_names_and_set_mtime? and not attributes[:source_date_epoch].nil?
        # Force deterministic file order and timestamp
        args += ["--sort=name", ("--mtime=@%s" % attributes[:source_date_epoch])]
        # gnu tar obeys GZIP environment variable with options for gzip; -n = forget original filename and date
        args.unshift({"GZIP" => "-9n"})
      end
      safesystem(*args)
    end

    logger.debug("Removing no longer needed control dir", :path => control_path)
  ensure
    FileUtils.rm_r(control_path)
  end # def write_control_tarball

  def write_control
    # warn user if epoch is set
    logger.warn("epoch in Version is set", :epoch => self.epoch) if self.epoch

    # calculate installed-size if necessary:
    if attributes[:deb_installed_size].nil?
      logger.info("No deb_installed_size set, calculating now.")
      total = 0
      Find.find(staging_path) do |path|
        stat = File.lstat(path)
        next if stat.directory?
        total += stat.size
      end
      # Per http://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Installed-Size
      #   "The disk space is given as the integer value of the estimated
      #    installed size in bytes, divided by 1024 and rounded up."
      attributes[:deb_installed_size] = total / 1024
    end

    # Write the control file
    control_path("control").tap do |control|
      if attributes[:deb_custom_control]
        logger.debug("Using '#{attributes[:deb_custom_control]}' template for the control file")
        control_data = File.read(attributes[:deb_custom_control])
      else
        logger.debug("Using 'deb.erb' template for the control file")
        control_data = template("deb.erb").result(binding)
      end

      logger.debug("Writing control file", :path => control)
      File.write(control, control_data)
      File.chmod(0644, control)
      edit_file(control) if attributes[:edit?]
    end
  end # def write_control

  # Write out the maintainer scripts
  #
  # SCRIPT_MAP is a map from the package ':after_install' to debian
  # 'post_install' names
  def write_scripts
    SCRIPT_MAP.each do |scriptname, filename|
      next unless script?(scriptname)

      control_path(filename).tap do |controlscript|
        logger.debug("Writing control script", :source => filename, :target => controlscript)
        File.write(controlscript, script(scriptname))
        # deb maintainer scripts are required to be executable
        File.chmod(0755, controlscript)
      end
    end
  end # def write_scripts

  def write_conffiles
    # expand recursively a given path to be put in allconfigs
    def add_path(path, allconfigs)
      # Strip leading /
      path = path[1..-1] if path[0,1] == "/"
      cfg_path = File.expand_path(path, staging_path)
      Find.find(cfg_path) do |p|
        if File.file?(p)
          allconfigs << p.gsub("#{staging_path}/", '')
        end
      end
    end

    # check for any init scripts or default files
    inits    = attributes.fetch(:deb_init_list, [])
    defaults = attributes.fetch(:deb_default_list, [])
    upstarts = attributes.fetch(:deb_upstart_list, [])
    etcfiles = []
    # Add everything in /etc
    begin
      if !attributes[:deb_no_default_config_files?] && File.exists?(staging_path("/etc"))
        logger.warn("Debian packaging tools generally labels all files in /etc as config files, " \
                    "as mandated by policy, so fpm defaults to this behavior for deb packages. " \
                    "You can disable this default behavior with --deb-no-default-config-files flag")
        add_path("/etc", etcfiles)
      end
    rescue Errno::ENOENT
    end

    return unless (config_files.any? or inits.any? or defaults.any? or upstarts.any? or etcfiles.any?)

    allconfigs = etcfiles

    # scan all conf file paths for files and add them
    config_files.each do |path|
      logger.debug("Checking if #{path} exists")
      cfe = File.exist?("#{path}")
      logger.debug("Check result #{cfe}")
      begin
        add_path(path, allconfigs)
      rescue Errno::ENOENT
        if !cfe
          raise FPM::InvalidPackageConfiguration,
            "Error trying to use '#{path}' as a config file in the package. Does it exist?"
        else
          dcl = File.join(staging_path, path)
          if !File.exist?("#{dcl}")
            logger.debug("Adding config file #{path} to Staging area #{staging_path}")
            FileUtils.mkdir_p(File.dirname(dcl))
            FileUtils.cp_r path, dcl
          else
            logger.debug("Config file aready exists in staging area.")
          end
        end
      end
    end

    if attributes[:deb_auto_config_files?]
      inits.each do |init|
        name = File.basename(init, ".init")
        initscript = "/etc/init.d/#{name}"
        logger.debug("Add conf file declaration for init script", :script => initscript)
        allconfigs << initscript[1..-1]
      end
      defaults.each do |default|
        name = File.basename(default, ".default")
        confdefaults = "/etc/default/#{name}"
        logger.debug("Add conf file declaration for defaults", :default => confdefaults)
        allconfigs << confdefaults[1..-1]
      end
      upstarts.each do |upstart|
        name = File.basename(upstart, ".upstart")
        upstartscript = "etc/init/#{name}.conf"
        logger.debug("Add conf file declaration for upstart script", :script => upstartscript)
        allconfigs << upstartscript[1..-1]
      end
    end

    allconfigs.sort!.uniq!
    return unless allconfigs.any?

    control_path("conffiles").tap do |conffiles|
      File.open(conffiles, "w") do |out|
        allconfigs.each do |cf|
          # We need to put the leading / back. Stops lintian relative-conffile error.
          out.puts("/" + cf)
        end
      end
      File.chmod(0644, conffiles)
    end
  end # def write_conffiles

  def write_shlibs
    return unless attributes[:deb_shlibs]
    logger.info("Adding shlibs", :content => attributes[:deb_shlibs])
    File.open(control_path("shlibs"), "w") do |out|
      out.write(attributes[:deb_shlibs])
    end
    File.chmod(0644, control_path("shlibs"))
  end # def write_shlibs

  def write_debconf
    if attributes[:deb_config]
      FileUtils.cp(attributes[:deb_config], control_path("config"))
      File.chmod(0755, control_path("config"))
    end

    if attributes[:deb_templates]
      FileUtils.cp(attributes[:deb_templates], control_path("templates"))
      File.chmod(0644, control_path("templates"))
    end
  end # def write_debconf

  def write_meta_files
    files = attributes[:deb_meta_file]
    return unless files
    files.each do |fn|
      dest = control_path(File.basename(fn))
      FileUtils.cp(fn, dest)
      File.chmod(0644, dest)
    end
  end

  def write_triggers
    lines = [['interest', :deb_interest],
             ['activate', :deb_activate],
             ['interest-noawait', :deb_interest_noawait],
             ['activate-noawait', :deb_activate_noawait],
             ].map { |label, attr|
      (attributes[attr] || []).map { |e| "#{label} #{e}\n" }
    }.flatten.join('')

    if lines.size > 0
      File.open(control_path("triggers"), 'a') do |f|
        f.chmod 0644
        f.write "\n" if f.size > 0
        f.write lines
      end
    end
  end

  def write_md5sums
    md5_sums = {}

    Find.find(staging_path) do |path|
      if File.file?(path) && !File.symlink?(path)
        md5 = Digest::MD5.file(path).hexdigest
        md5_path = path.gsub("#{staging_path}/", "")
        md5_sums[md5_path] = md5
      end
    end

    if not md5_sums.empty?
      File.open(control_path("md5sums"), "w") do |out|
        md5_sums.each do |path, md5|
          out.puts "#{md5}  #{path}"
        end
      end
      File.chmod(0644, control_path("md5sums"))
    end
  end # def write_md5sums

  def mkdir_p(dir)
    FileUtils.mkdir_p(dir, :mode => 0755)
  end

  def to_s(format=nil)
    # Default format if nil
    # git_1.7.9.3-1_amd64.deb
    return super(format.nil? ? "NAME_FULLVERSION_ARCH.EXTENSION" : format)
  end # def to_s

  def data_tar_flags
    data_tar_flags = []
    if attributes[:deb_use_file_permissions?].nil?
      if !attributes[:deb_user].nil?
        if attributes[:deb_user] == 'root'
          data_tar_flags += [ "--numeric-owner", "--owner", "0" ]
        else
          data_tar_flags += [ "--owner", attributes[:deb_user] ]
        end
      end

      if !attributes[:deb_group].nil?
        if attributes[:deb_group] == 'root'
          data_tar_flags += [ "--numeric-owner", "--group", "0" ]
        else
          data_tar_flags += [ "--group", attributes[:deb_group] ]
        end
      end
    end
    return data_tar_flags
  end # def data_tar_flags

  public(:input, :output, :architecture, :name, :prefix, :converted_from, :to_s, :data_tar_flags)
end # class FPM::Target::Deb
