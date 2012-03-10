require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "fileutils"
require "insist"

class FPM::Package::Deb < FPM::Package
  # Map of what scripts are named.
  SCRIPT_MAP = {
    :before_install     => "preinst",
    :after_install      => "postinst",
    :before_remove      => "prerm",
    :after_remove       => "postrm",
  }

  option "--ignore-iteration-in-dependencies", :flag, 
            "For '=' (equal) dependencies, allow iterations on the specified " \
            "version. Default is to be specific. This option allows the same " \
            "version of a package but any iteration is permitted"

  option "--pre-depends", "DEPENDENCY",
    "Add DEPENDENCY as a Pre-Depends" do |val|
    @pre_depends ||= []
    @pre_depends << dep
  end

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
        @architecture = %{uname -m}.chomp if $?.exitstatus != 0
      else
        @architecture = %x{uname -m}.chomp
      end
    end
    if @architecture == "x86_64"
      # Debian calls x86_64 "amd64"
      @architecture = "amd64"
    end
    if @architecture == "i386"
      # Debian calls i386 "i686"
      @architecture = "i686"
    end

    return @architecture
  end # def architecture

  # Get the name of this package. See also FPM::Package#name
  #
  # This accessor actually modifies the name if it has some invalid or unwise
  # characters.
  def name
    if @name =~ /[A-Z]/
      @logger.warn("Debian tools (dpkg/apt) don't do well with packages " \
        "that use capital letters in the name. In some cases it will " \
        "automatically downcase them, in others it will not. It is confusing." \
        "Best to not use any capital letters at all.",
        :oldname => @name, :fixedname => @name.downcase)
      @name = @name.downcase
    end

    if @name.include?("_")
      @logger.info("Package name includes underscores, converting to dashes",
                   :name => @name)
      @name = @name.gsub(/[_]/, "-")
    end

    return @name
  end # def name

  def input(input_path)
    extract_info(input_path)
    extract_files(input_path)
  end # def input

  def extract_info(package)
    with(build_path("control")) do |path|
      FileUtils.mkdir(path) if !File.directory?(path)
      # Unpack the control tarball
      safesystem("ar p #{package} control.tar.gz | tar -zxf - -C #{path}")

      control = File.read(File.join(path, "control"))

      parse = lambda do |field| 
        value = control[/^#{field.capitalize}: .*/]
        if value.nil?
          return nil
        else
          value.split(": ",2).last
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

      # The description field is a special flower, parse it that way.
      # The description is the first line as a normal Description field, but also continues
      # on future lines indented by one space, until the end of the file. Blank
      # lines are marked as ' .'
      description = control[/^Description: .*/m].split(": ", 2).last
      self.description = description.gsub(/^ /, "").gsub(/^\.$/, "")

      #self.config_files = config_files

      self.dependencies += parse_depends(parse.call("Depends"))
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
    # unpack the data.tar.gz from the deb package into staging_path
    safesystem("ar p #{package} data.tar.gz | tar -zxf - -C #{staging_path}")
  end # def extract_files

  def output(output_path)
    insist { File.directory?(build_path) } == true

    # Abort if the target path already exists.
    raise FileAlreadyExists.new(output_path) if File.exists?(output_path)

    # create 'debian-binary' file, required to make a valid debian package
    File.write(build_path("debian-binary"), "2.0\n")

    write_control_tarball

    # Tar up the staging_path and call it 'data.tar.gz'
    datatar = build_path("data.tar.gz")
    safesystem(tar_cmd, "-C", staging_path, "-zcf", datatar, ".")

    # pack up the .deb, which is just an 'ar' archive with 3 files
    # the 'debian-binary' file has to be first
    with(File.expand_path(output_path)) do |output_path|
      ::Dir.chdir(build_path) do
        safesystem("ar", "-qc", output_path, "debian-binary", "control.tar.gz", datatar)
      end
    end
    @logger.log("Created deb package", :path => output_path)
  end # def output

  def default_output
    if iteration
      "#{name}_#{version}-#{iteration}_#{architecture}.#{type}"
    else
      "#{name}_#{version}_#{architecture}.#{type}"
    end
  end # def default_output

  def converted_from(origin)
    self.dependencies = self.dependencies.collect do |dep|
      fix_dependency(dep)
    end.flatten
  end # def converted_from

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
        dep = "#{name} (#{op} #{version})"
      end
    end

    name_re = /^[^ \(]+/
    name = dep[name_re]
    if name =~ /[A-Z]/
      @logger.warn("Downcasing dependency '#{name}' because deb packages " \
                   " don't work so good with uppercase names")
      dep.gsub!(name_re) { |n| n.downcase }
    end

    if dep.include?("_")
      @logger.warn("Replacing underscores with dashes in '#{dep}' because " \
                   "debs don't like underscores")
      dep.gsub!("_", "-")
    end

    # Convert gem ~> X.Y.Z to '>= X.Y.Z' and << X.Y+1.0
    if dep =~ /\(~>/
      name, version = dep.gsub(/[()~>]/, "").split(/ +/)[0..1]
      nextversion = version.split(".").collect { |v| v.to_i }
      l = nextversion.length
      nextversion[l-2] += 1
      nextversion[l-1] = 0
      nextversion = nextversion.join(".")
      return ["#{name} (>= #{version})", "#{name} (<< #{nextversion})"]
    elsif (m = dep.match(/(\S+)\s+\(= (.+)\)/))
      # Convert 'foo (= x)' to 'foo (>= x)' and 'foo (<< x+1)'
      name, version = m[1..2]
      nextversion = version.split('.').collect { |v| v.to_i }
      nextversion[-1] += 1
      nextversion = nextversion.join(".")
      return ["#{name} (>= #{version})", "#{name} (<< #{nextversion})"]
    else
      # otherwise the dep is probably fine
      return dep
    end
  end # def fix_dependency

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
    write_scripts # write the maintainer scripts
    write_conffiles # write the conffiles
    write_debconf # write the debconf files

    # Make the control.tar.gz
    with(build_path("control.tar.gz")) do |controltar|
      @logger.info("Creating", :path => controltar, :from => control_path)
      safesystem(tar_cmd, "--numeric-owner", "--owner=0", "--group=0", "-zcf",
                 controltar, "-C", control_path, ".")
    end

    @logger.debug("Removing no longer needed control dir", :path => control_path)
  ensure
    FileUtils.rm_r(control_path)
  end # def write_control_tarball

  def write_control
    # calculate installed-size if necessary:
    if attributes[:deb_installed_size].nil?
      @logger.info("No deb_installed_size set, calculating now.")
      total = 0
      Find.find(staging_path) do |path|
        stat = File.stat(path)
        next if stat.directory?
        total += stat.size
      end
      # Per http://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Installed-Size
      #   "The disk space is given as the integer value of the estimated
      #    installed size in bytes, divided by 1024 and rounded up."
      attributes[:deb_installed_size] = total / 1024
    end

    # Write the control file
    with(control_path("control")) do |control|
      if attributes["deb-custom-control"] 
        @logger.debug("Using '#{attributes["deb-custom-control"]}' template for the control file")
        control_data = File.read(attributes["deb-custom-control"])
      else
        @logger.debug("Using 'deb.erb' template for the control file")
        control_data = template("deb.erb").result(binding)
      end

      @logger.debug("Writing control file", :path => control)
      File.write(control, control_data)
      edit_file(control) if attributes[:edit?]
    end
  end # def write_control

  # Write out the maintainer scripts
  #
  # SCRIPT_MAP is a map from the package ':after_install' to debian
  # 'post_install' names
  def write_scripts
    SCRIPT_MAP.each do |script, filename|
      next if scripts[script].nil?

      with(control_path(filename)) do |path|
        FileUtils.cp(scripts[script], filename)
        # deb maintainer scripts are required to be executable
        File.chmod(0755, filename)
      end
    end 
  end # def write_scripts

  def write_conffiles
    File.open(control_path("conffiles"), "w") do |out|
      # 'config_files' comes from FPM::Package and is usually set with
      # FPM::Command's --config-files flag
      config_files.each { |cf| out.puts(cf) }
    end
  end # def write_conffiles

  def write_debconf
    if attributes[:deb_config]
      FileUtils.cp(attributes[:deb_config], control_path("config"))
      File.chmod(0755, control_path("config"))
    end

    if attributes[:deb_templates]
      FileUtils.cp(attributes[:deb_templates], control_path("templates"))
      File.chmod(0755, control_path("templates"))
    end
  end # def write_debconf

  public(:input, :output, :architecture, :name, :converted_from)
end # class FPM::Target::Deb
