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
    # Make the control
    system("tar -zcf control.tar.gz control md5sums")

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

