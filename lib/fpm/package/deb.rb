require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "fileutils"

class FPM::Package::Deb < FPM::Package
  # Installed size
  attr_accessor :installed_size

  # Supported Debian control files
  CONTROL_FILES = {
    "pre-install"       => [:script, "preinst"],
    "post-install"      => [:script, "postinst"],
    "pre-uninstall"     => [:script, "prerm"],
    "post-uninstall"    => [:script, "postrm"],
    "debconf-config"    => [:script, "config"],
    "debconf-templates" => [:text,   "templates"]
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

  option "--installed-size", "BYTES",
    "The installed size, in bytes" do |installed_size_s|
    installed_size_s.to_i
  end

  # Return the architecture. This will default to native if not yet set.
  # It will also try to use dpkg and 'uname -m' to figure out what the
  # native 'architecture' value should be.
  def architecture
    if @architecture.nil? or @architecture == "native"
      # Default architecture should be 'native' which we'll need
      # to ask the system about.
      # TODO(sissel): only run dpkg if we can find it in the path.
      if program_in_path?("dpkg")
        @architecture = %x{dpkg --print-architecture 2> /dev/null}.chomp
        @architecture = %{uname -m}.chomp if $?.exitstatus != 0
      else
        @architecture = %x{uname -m}.chomp
      end
    elsif @architecture == "x86_64"
      # Debian calls x86_64 "amd64"
      @architecture = "amd64"
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
      @logger.info("Package name ncludes underscores, converting to dashes",
                   :name => @name)
      @name = @name.gsub(/[_]/, "-")
    end

    return @name
  end # def name

  def output(output_path)
    # Use custom Debian control file when given ...
    FileUtils.mkdir(build_path("control"))

    # TODO(sissel): Support the flag letting people specify their own control file
    # TODO(sissel): --deb-custom-control
    # TODO(sissel): Support putting the maintainer scripts in the controldir
    # TODO(sissel): Make sure the maintainer scripts are executable
    # TODO(sissel): Write 'config_files' to controldir/'conffiles'

    with(control_path("control")) do |control|
      control_data = template("deb.erb").result(binding)
      @logger.debug("Writing control file", :path => control)
      File.write(control, control_data)
    end

    # Make the control.tar.gz
    with(build_path("control.tar.gz")) do |controltar|
      @logger.info("Creating", :path => controltar, :from => control_path)
      safesystem(tar_cmd, "--numeric-owner", "--owner=0", "--group=0", "-zcf",
                 controltar, "-C", control_path, ".")
    end
    @logger.debug("Removing no longer needed control dir", :path => control_path)
    FileUtils.rm_r(build_path("control"))

    # create debian-binary file, required to make a valid debian package
    File.write(build_path("debian-binary"), "2.0")

    # TODO(sissel): Tar up the staging_dir and call it 'data.tar.gz'
    datatar = build_path("data.tar.gz")
    safesystem(tar_cmd, "-C", staging_path, "-zcf", datatar, ".")

    # pack up the .deb
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

  # TODO(sissel): support pre_dependencies
  #def pre_dependencies
    #self.settings[:pre_depends] || []
  #end # def pre_dependencies
  #
  
  def control_path(path=nil)
    @control_path ||= build_path("control")
    File.mkdir(@control_path) if !File.directory?(@control_path)

    if path.nil?
      return @control_path
    else
      return File.join(@control_path, path)
    end
  end # def control_path
  public(:input, :output)
end # class FPM::Target::Deb
