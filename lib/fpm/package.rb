require "fpm/namespace"
require "fpm/util"
require "socket" # for Socket.gethostname
require "cabin"
require "tmpdir"

# This class is the parent of all packages.
# If you want to implement an FPM package type, you'll inherit from this.
#
# There are 
class FPM::Package
  include FPM::Util

  # This class is raised if there's something wrong with a setting in the package.
  class InvalidArgument < StandardError; end

  # The name of this package
  attr_accessor :name

  # The version of this package (the upstream version)
  attr_accessor :version

  # The epoch version of this package
  # This is used most when an upstream package changes it's versioning
  # style so standard comparisions wouldn't work.
  attr_accessor :epoch

  # The iteration of this package.
  #   Debian calls this 'release' and is the last '-NUMBER' in the version
  #   RedHat has this as 'Release' in the .spec file
  #   FreeBSD calls this 'PORTREVISION'
  #
  # Iteration can be nil. If nil, the fpm package implementation is expected
  # to handle any default value that should be instead.
  attr_accessor :iteration

  # Who maintains this package? This could be the upstream author
  # or the package maintainer. You pick.
  attr_accessor :maintainer

  # A identifier representing the vendor. Any string is fine.
  # This is usually who produced the software.
  attr_accessor :vendor

  # URL for this package.
  # Could be the homepage. Could be the download url. You pick.
  attr_accessor :url

  # The category of this package.
  # RedHat calls this 'Group'
  # Debian calls this 'Section'
  # FreeBSD would put this in /usr/ports/<category>/...
  attr_accessor :category

  # A identifier representing the license. Any string is fine.
  attr_accessor :license

  # What architecture is this package for?
  attr_accessor :architecture

  # Array of dependencies.
  attr_accessor :dependencies

  # Array of things this package provides.
  # (Not all packages support this)
  attr_accessor :provides

  # Array of things this package conflicts with.
  # (Not all packages support this)
  attr_accessor :conflicts

  # Array of things this package replaces.
  # (Not all packages support this)
  attr_accessor :replaces

  # a summary or description of the package
  attr_accessor :description

  # hash of paths for maintainer/package scripts (postinstall, etc)
  attr_accessor :scripts

  # Array of configuration files
  attr_accessor :config_files

  # Any other attributes specific to this package.
  # This is where you'd put rpm, deb, or other specific attributes.
  attr_accessor :attributes

  class << self
    # This method is invoked when subclass occurs.
    # 
    # Lets us track all known FPM::Package subclasses
    def inherited(klass)
      @subclasses ||= {}
      @subclasses[klass.name.gsub(/.*:/, "").downcase] = klass
    end # def self.inherited

    # Get a list of all known package subclasses
    def types
      return @subclasses
    end # def self.types

    # This allows packages to define flags for the fpm command line
    def option(flag, param, help, options={}, &block)
      @options ||= []
      if !flag.is_a?(Array)
        flag = [flag]
      end

      flag = flag.collect { |f| "--#{type}-#{f.gsub(/^--/, "")}" }
      help = "(#{type} only) #{help}"
      @options << [flag, param, help, options, block]
    end # def options

    # Apply the options for this package on the clamp command
    def apply_options(clampcommand)
      @options ||= []
      @options.each do |args|
        flag, param, help, options, block = args
        clampcommand.option(flag, param, help, options, &block)
      end
    end # def apply_options

    # Get the type of this package class.
    #
    # For "Foo::Bar::BAZ" this will return "baz"
    def type
      self.name.split(':').last.downcase
    end # def self.type
  end # class << self

  private

  def initialize
    @logger = Cabin::Channel.get

    # Attributes for this specific package 
    @attributes = {}

    # Reference
    # http://www.debian.org/doc/manuals/maint-guide/first.en.html
    # http://wiki.debian.org/DeveloperConfiguration
    # https://github.com/jordansissel/fpm/issues/37
    if ENV.include?("DEBEMAIL") and ENV.include?("DEBFULLNAME")
      # Use DEBEMAIL and DEBFULLNAME as the default maintainer if available.
      @maintainer = "#{ENV["DEBFULLNAME"]} <#{ENV["DEBEMAIL"]}>"
    else
      # TODO(sissel): Maybe support using 'git config' for a default as well?
      # git config --get user.name, etc can be useful.
      #
      # Otherwise default to user@currenthost
      @maintainer = "<#{ENV["USER"]}@#{Socket.gethostname}>"
    end

    @architecture = "all"
    @description = "no description given"
    @version = 1.0
    @epoch = 1
    @iteration = nil
    @url = nil
    @category = "default"
    @license = "unknown"
    @vendor = "none"

    @provides = []
    @conflicts = []
    @replaces = []
    @dependencies = []
    @scripts = {}
    @config_files = []

    staging_path
    build_path
  end # def initialize

  # TODO [Jay]: make this better...?
  def type
    self.class.type
  end # def type

  # Convert this package to a new package type
  def convert(klass)
    @logger.info("Converting #{self.type} to #{klass.type}")
    pkg = klass.new
    pkg.instance_variable_set(:@staging_path, staging_path)

    # copy other bits
    ivars = [
      :@architecture, :@attributes, :@category, :@config_files, :@conflicts,
      :@dependencies, :@description, :@epoch, :@iteration, :@license, :@maintainer,
      :@name, :@provides, :@replaces, :@scripts, :@url, :@vendor, :@version,
      :@config_files
    ]
    ivars.each do |ivar|
      #@logger.debug("Copying ivar", :ivar => ivar, :value => instance_variable_get(ivar),
                    #:from => self.type, :to => pkg.type)
      pkg.instance_variable_set(ivar, instance_variable_get(ivar))
    end

    pkg.converted_from(self.class)
    return pkg
  end # def convert

  # This method is invoked on a package when it has been covered to a new
  # package format. The purpose of this method is to do any extra conversion
  # steps, like translating dependency conditions, etc.
  def converted_from(origin)
    # nothing to do by default. Subclasses may implement this.
    # See the RPM package class for an example.
  end # def converted

  # Add a new source to this package.
  # The exact behavior depends on the kind of package being managed.
  #
  # For instance: 
  #
  # * for FPM::Package::Dir, << expects a path to a directory or files.
  # * for FPM::Package::RPM, << expects a path to an rpm.
  #
  # The idea is that you can keep pumping in new things to a package
  # for later conversion or output.
  #
  # Implementations are expected to put files relevant to the 'input' in the
  # staging_path
  def input(thing_to_input)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "reading #{self.type} packages")
  end # def input

  # Output this package to the given path.
  def output(path)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "creating #{self.type} packages")
  end # def output

  def staging_path(path=nil)
    @staging_path ||= ::Dir.mktmpdir(File.join(::Dir.pwd, "package-#{type}-staging"))

    if path.nil?
      return @staging_path
    else
      return File.join(@staging_path, path)
    end
  end # def staging_path

  def build_path(path=nil)
    @build_path ||= ::Dir.mktmpdir(File.join(::Dir.pwd, "package-#{type}-build"))

    if path.nil?
      return @build_path
    else
      return File.join(@build_path, path)
    end
  end # def build_path

  # Clean up any temporary storage used by this class.
  def cleanup
    if File.directory?(staging_path)
      @logger.debug("Cleaning up", :path => staging_path)
      FileUtils.rm_r(staging_path) 
    end

    if File.directory?(build_path)
      @logger.debug("Cleaning up", :path => build_path)
      FileUtils.rm_r(build_path) 
    end
  end # def cleanup

  # List all files in the staging_path
  #
  # The paths will all be relative to staging_path and will not include that
  # path.
  def files
    # Find will print the path you're searching first, so skip it and return
    # the rest. Also trim the leading path such that '#{staging_path}/' is removed
    # from the path before returning.
    return Find.find(staging_path) \
      .select { |path| path != staging_path } \
      .collect { |path| path[staging_path.length + 1.. -1] }
  end # def files
 
  def template(path)
    require "erb"
    template_dir = File.join(File.dirname(__FILE__), "..", "..", "templates")
    template_path = File.join(template_dir, path)
    template_code = File.read(template_path)
    @logger.info("Reading template", :path => template_path)
    erb = ERB.new(template_code, nil, "-")
    erb.filename = template_path
    return erb
  end # def template

  def to_s(fmt="NAME.TYPE")
    fullversion = version.to_s
    fullversion += "-#{iteration}" if iteration
    return fmt.gsub("ARCH", architecture.to_s) \
      .gsub("NAME", name.to_s) \
      .gsub("FULLVERSION", fullversion) \
      .gsub("VERSION", version.to_s) \
      .gsub("EPOCH", epoch.to_s)
      .gsub("TYPE", type.to_s)
  end # def to_s

  public(:type, :initialize, :convert, :output, :input, :cleanup, :staging_path, :files, :to_s, :converted_from)
end # class FPM::Package
