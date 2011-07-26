require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"

class FPM::Target::Deb < FPM::Package

  def self.flags(opts, settings)
    settings.target[:deb] = "deb"

    opts.on("--ignore-iteration-in-dependencies",
            "For = dependencies, allow iterations on the specified version.  Default is to be specific.") do |x|
      settings.target[:ignore_iteration] = true
    end

    opts.on("--pre-depends DEPENDENCY", "Add DEPENDENCY as Pre-Depends.") do |dep|
      (settings.target[:pre_depends] ||= []) << dep
    end
  end

  def needs_md5sums
    true
  end # def needs_md5sums

  def architecture
    if @architecture.nil? or @architecture == "native"
      # Default architecture should be 'native' which we'll need
      # to ask the system about.
      arch = %x{dpkg --print-architecture}.chomp
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
    control_files = [ "control", "md5sums" ]
    # place the postinst prerm files
    self.scripts.each do |name, path|
      case name
        when "pre-install"
          system("cp #{path} ./preinst")
          control_files << "preinst"
        when "post-install"
          system("cp #{path} ./postinst")
          control_files << "postinst"
        when "pre-uninstall"
          system("cp #{path} ./prerm")
          control_files << "prerm"
        when "post-uninstall"
          system("cp #{path} ./postrm")
          control_files << "postrm"
        else raise "Unsupported script name '#{name}' (path: #{path})"
      end # case name
    end # self.scripts.each

    if self.config_files.any?
      File.open('conffiles', 'w'){ |f| f.puts(config_files.join("\n")) }
      control_files << 'conffiles'
    end

    # Make the control
    system("tar -zcf control.tar.gz #{control_files.map{ |f| "./#{f}" }.join(" ")}")

    # create debian-binary
    File.open("debian-binary", "w") { |f| f.puts "2.0" }

    # pack up the .deb
    system("ar -qc #{params[:output]} debian-binary control.tar.gz data.tar.gz")
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
