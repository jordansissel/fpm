require "erb"
require "fpm/namespace"
require "fpm/package"

class FPM::Target::Deb < FPM::Package
  # Debian calls x86_64 "amd64"
  def architecture
    if @architecture == "x86_64"
      "amd64"
    else
      @architecture
    end
  end

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

