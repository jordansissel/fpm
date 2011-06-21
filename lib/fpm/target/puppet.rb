require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "etc"

class ::Dir
  class << self
    alias :orig_mkdir :mkdir

    def mkdir(*args)
      p :mkdir => { :args => args, :caller => caller }
      orig_mkdir(*args)
    end
  end
end

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
  
  # Default specfile generator just makes one specfile, whatever that is for
  # this package.
  def generate_specfile(builddir)
    paths = []
    @source.paths.each do |path|
      Find.find(path) { |p| paths << p }
    end
    manifests = %w{package.pp package/remove.pp}
    manifests.each do |name|
      dir = File.join(builddir, File.dirname(name))
      @logger.info("manifests targeting: #{dir}")
      Dir.mkdir(dir) if !File.directory?(dir)
      
      @logger.info("Generating #{name}")
      File.open(File.join(builddir, name), "w") do |f|
        f.puts template(File.join("puppet", "#{name}.erb")).result(binding)
      end
    end
  end # def generate_specfile

  # Override render_spec so we can generate multiple files for puppet.
  # The package.pp, package/remove.pp, 
  def render_spec
    # find all files in paths given.
    paths = []
    @source.paths.each do |path|
      Find.find(path) { |p| paths << p }
    end
    #@logger.info(:paths => paths.sort)
    template.result(binding)
  end # def render_spec
  def unpack_data_to
    "files"
  end

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

    if File.exists?(params[:output])
      # TODO(sissel): Allow folks to choose output?
      @logger.error("Puppet module directory '#{params[:output]}' already " \
                    "exists. Delete it or choose another output (-p flag)")
    end

    Dir.mkdir(params[:output])
    builddir = Dir.pwd

    Dir.chdir(params[:output]) do
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

