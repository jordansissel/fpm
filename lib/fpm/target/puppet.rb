require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"

# TODO(sissel): Add dependency checking support.
# IIRC this has to be done as a 'checkinstall' step.
class FPM::Target::Puppet < FPM::Package
  def architecture
    case @architecture
    when nil, "native"
      @architecture = %x{uname -m}.chomp
    end
    return @architecture
  end # def architecture

  def specfile(builddir)
    "#{builddir}/pacakge.pp"
  end # def specfile

  def build!(params)
    self.scripts.each do |name, path|
      case name
        when "pre-install"
        when "post-install"
        when "pre-uninstall"
        when "post-uninstall"
      end # case name
    end # self.scripts.each

    # Unpack data.tar.gz
    Dir.mkdir("files")
    Dir.mkdir("manifests")
    system("gzip -d data.tar.gz");
    Dir.chdir("files") { system("tar -xf ../data.tar") }

    # Files are now in the 'files' path
    # Generate a manifest 'package.pp' with all the information from
  end # def build!

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

