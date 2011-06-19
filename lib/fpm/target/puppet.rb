require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "etc"

require "fileutils" # for FileUtils

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
    "#{builddir}/package.pp"
  end # def specfile

  def build!(params)
    # TODO(sissel): Support these somehow, perhaps with execs and files.
    self.scripts.each do |name, path|
      case name
        when "pre-install"
        when "post-install"
        when "pre-uninstall"
        when "post-uninstall"
      end # case name
    end # self.scripts.each

    Dir.mkdir(params[:output])
    builddir = Dir.pwd
    data_tarball = File.join(builddir, "data.tar.gz")

    Dir.chdir(params[:output]) do
      # Unpack data.tar.gz
      Dir.mkdir("files")
      system("gzip -d #{data_tarball}");
      Dir.chdir("files") { system("tar -xf #{data_tarball.gsub(/.gz$/, "")}") }

      Dir.mkdir("manifests")
      FileUtils.cp(specfile(builddir), "manifests")
    end
    # Files are now in the 'files' path
    # Generate a manifest 'package.pp' with all the information from
  end # def build!

  # The directory we create should just be the name of the package as the
  # module name
  def default_output
    name
  end # def default_output

  def puppetsort(hash)
    # TODO(sissel): Implement sorting that follows the puppet style guide
    # Such as, 'ensure' goes first, etc.
    return hash.to_a
  end # def puppetsort

  def uid2user(uid)
    begin
      pwent = Etc.getpwuid(uid)
      return pwent.name
    rescue ArgumentError => e
      # Invalid user id? No user? Return the uid.
      @logger.warn("Failed to find username for uid #{uid}")
      return uid.to_s
    end
  end # def uid2user

  def gid2group(gid)
    begin
      grent = Etc.getgrgid(gid)
      return grent.name
    rescue ArgumentError => e
      # Invalid user id? No user? Return the uid.
      @logger.warn("Failed to find group for gid #{gid}")
      return gid.to_s
    end
  end # def uid2user
end # class FPM::Target::Puppet

