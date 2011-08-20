require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"

# TODO(sissel): Add dependency checking support.
# IIRC this has to be done as a 'checkinstall' step.
class FPM::Target::Solaris < FPM::Package
  def architecture
    case @architecture
    when nil, "native"
      @architecture = %x{uname -p}.chomp
    end
    # "all" is a valid arch according to
    # http://www.bolthole.com/solaris/makeapackage.html

    return @architecture
  end # def architecture

  def specfile(builddir)
    "#{builddir}/pkginfo"
  end

  def build!(params)
    self.scripts.each do |name, path|
      case name
        when "pre-install"
          safesystem("cp #{path} ./preinstall")
          File.chmod(0755, "./preinstall")
        when "post-install"
          safesystem("cp #{path} ./postinstall")
          File.chmod(0755, "./postinstall")
        when "pre-uninstall"
          raise FPM::InvalidPackageConfiguration.new(
            "pre-uninstall is not supported by Solaris packages"
          )
        when "post-uninstall"
          raise FPM::InvalidPackageConfiguration.new(
            "post-uninstall is not supported by Solaris packages"
          )
      end # case name
    end # self.scripts.each

    # Unpack data.tar.gz so we can build a package from it.
    Dir.mkdir("data")
    safesystem("gzip -d data.tar.gz");
    Dir.chdir("data") do
      safesystem("tar -xf ../data.tar");
    end

    #system("(echo 'i pkginfo'; pkgproto data=/) > Prototype")

    # Generate the package 'Prototype' file
    # TODO(sissel): allow setting default file owner.
    File.open("Prototype", "w") do |prototype|
      prototype.puts("i pkginfo")
      prototype.puts("i preinstall") if self.scripts["pre-install"]
      prototype.puts("i postinstall") if self.scripts["post-install"]

      # TODO(sissel): preinstall/postinstall
      IO.popen("pkgproto data=/").each_line do |line|
        type, klass, path, mode, user, group = line.split
        # Override stuff in pkgproto
        # TODO(sissel): Make this tunable?
        user = "root"
        group = "root"
        prototype.puts([type, klass, path, mode, user, group].join(" "))
      end # popen "pkgproto ..."
    end # File prototype

    # Should create a package directory named by the package name.
    safesystem("pkgmk -o -d .")

    # Convert the 'package directory' built above to a real solaris package.
    safesystem("pkgtrans -s . #{params[:output]} #{name}")
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

