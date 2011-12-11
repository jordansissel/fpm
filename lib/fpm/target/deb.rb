require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"

class FPM::Target::Deb < FPM::Package

  # Supported Debian control files
  CONTROL_FILES = {
    "pre-install"       => [:script, "preinst"],
    "post-install"      => [:script, "postinst"],
    "pre-uninstall"     => [:script, "prerm"],
    "post-uninstall"    => [:script, "postrm"],
    "debconf-config"    => [:script, "config"],
    "debconf-templates" => [:text,   "templates"]
  }

  def self.flags(opts, settings)
    settings.target[:deb] = "deb"

    opts.on("--ignore-iteration-in-dependencies",
            "For = dependencies, allow iterations on the specified version.  Default is to be specific.") do |x|
      settings.target[:ignore_iteration] = true
    end

    opts.on("--pre-depends DEPENDENCY", "Add DEPENDENCY as Pre-Depends.") do |dep|
      (settings.target[:pre_depends] ||= []) << dep
    end

    # Take care about the case when we want custom control file but still use fpm ...
    opts.on("--custom-control FILEPATH",
            "Custom version of the Debian control file.") do |control|
      settings.target[:control] = File.expand_path(control)
    end
    
    # Add custom debconf config file
    opts.on("--config SCRIPTPATH",
            "Add SCRIPTPATH as debconf config file.") do |config|
      settings.scripts["debconf-config"] = File.expand_path(config)
    end
    
    # Add custom debconf templates file
    opts.on("--templates FILEPATH",
            "Add FILEPATH as debconf templates file.") do |templates|
      settings.scripts["debconf-templates"] = File.expand_path(templates)
    end
  end

  def needs_md5sums
    case %x{uname -s}.chomp
    when "Darwin"
      return false
    else
      return true
    end
  end # def needs_md5sums

  def architecture
    if @architecture.nil? or @architecture == "native"
      # Default architecture should be 'native' which we'll need
      # to ask the system about.
      arch = %x{dpkg --print-architecture 2> /dev/null}.chomp
      if $?.exitstatus != 0
        arch = %x{uname -m}.chomp
        @logger.warn("Can't find 'dpkg' tool (need it to get default " \
                     "architecture!). Please specificy --architecture " \
                     "specifically. (Defaulting now to #{arch})")
      end
      @architecture = arch
    elsif @architecture == "x86_64"
      # Debian calls x86_64 "amd64"
      @architecture = "amd64"
    end

    return @architecture
  end # def architecture

  def specfile(builddir)
    "#{builddir}/control"
  end

  def name
    if @name =~ /[A-Z]/
      @logger.warn("Debian tools (dpkg/apt) don't do well with packages " \
        "that use capital letters in the name. In some cases it will " \
        "automatically downcase them, in others it will not. It is confusing." \
        "Best to not use any capital letters at all.")
      @name = @name.downcase
    end

    if @name.include?("_")
      @logger.info("Package name '#{@name}' includes underscores, converting" \
                   " to dashes")
      @name = @name.gsub(/[_]/, "-")
    end

    return @name
  end

  def build!(params)
    control_files = [ "control" ]
    if File.exists? "./md5sums"
      control_files << "md5sums"
    end

    # Use custom Debian control file when given ...
    if self.settings[:control]
      %x{cp #{self.settings[:control]} ./control 2> /dev/null 2>&1}
      @logger.warn("Unable to process custom Debian control file (exit " \
                   "code: #{$?.exitstatus}). Falling back to default " \
                   "template.") unless $?.exitstatus == 0
    end

    # place the control files
    self.scripts.each do |name, path|
      ctrl_type, ctrl_file = CONTROL_FILES[name]
      if ctrl_file
        safesystem("cp",  path, "./#{ctrl_file}")
        safesystem("chmod", "a+x", "./#{ctrl_file}") if ctrl_type == :script
        control_files << ctrl_file
      else
        raise "Unsupported script name '#{name}' (path: #{path})"
      end
    end # self.scripts.each

    if self.config_files.any?
      File.open('conffiles', 'w'){ |f| f.puts(config_files.join("\n")) }
      control_files << 'conffiles'
    end

    # Make the control
    safesystem("tar", "--numeric-owner", "--owner=root", "--group=root",
               "-zcf", "control.tar.gz", *control_files)

    # create debian-binary
    File.open("debian-binary", "w") { |f| f.puts "2.0" }

    # pack up the .deb
    safesystem("ar", "-qc", "#{params[:output]}", "debian-binary", "control.tar.gz", "data.tar.gz")
  end # def build

  def default_output
    if iteration
      "#{name}_#{version}-#{iteration}_#{architecture}.#{type}"
    else
      "#{name}_#{version}_#{architecture}.#{type}"
    end
  end # def default_output

  def fix_dependency(dep)
    if dep =~ /[\(,\|]/
      # Don't "fix" ones that could appear well formed already.
    else
      da = dep.split(/ +/)
      if da.size > 1
        # Convert strings 'foo >= bar' to 'foo (>= bar)'
        dep = "#{da[0]} (#{da[1]} #{da[2]})"
      end
    end

    name_re = /^[^ \(]+/
    name = dep[name_re]
    if name =~ /[A-Z]/
      @logger.warn("Downcasing dependency '#{name}' because deb packages " \
                   " don't work so good with uppercase names")
      dep.gsub!(name_re) { |n| n.downcase }
    end

    if dep =~ /_/
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
    # ignore iterations for = dependencies if flag specified
    elsif (m = dep.match(/(\S+)\s+\(= (.+)\)/)) && self.settings[:ignore_iteration]
      name, version = m[1..2]
      nextversion = version.split('.').collect { |v| v.to_i }
      nextversion[-1] += 1
      nextversion = nextversion.join(".")
      return ["#{name} (>= #{version})", "#{name} (<< #{nextversion})"]
    else
      return dep
    end
  end # def fix_dependency

  def pre_dependencies
    self.settings[:pre_depends] || []
  end # def pre_dependencies
end # class FPM::Target::Deb
