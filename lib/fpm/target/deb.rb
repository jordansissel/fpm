require "erb"
require "fpm/namespace"
require "fpm/package"

class FPM::Target::Deb < FPM::Package
  def architecture
    if @architecture.nil? or @architecture == "native"
      # Default architecture should be 'native' which we'll need
      # to ask the system about.
      arch = %x{dpkg --print-architecture}.chomp
      if $?.exitstatus != 0
        arch = %x{uname -m}
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
    
    # Make the control
    system("tar -zcf control.tar.gz #{control_files.join(" ")}")

    # create debian-binary
    File.open("debian-binary", "w") { |f| f.puts "2.0" }

    # pack up the .deb
    system("ar -qc #{params[:output]} debian-binary control.tar.gz data.tar.gz")
  end # def build

  def default_output
    v = version
    v = "#{epoch}:#{v}" if epoch
    if iteration
      "#{name}_#{v}-#{iteration}_#{architecture}.#{type}"
    else
      "#{name}_#{v}_#{architecture}.#{type}"
    end
  end # def default_output
end # class FPM::Deb

