require "fpm/namespace"
require "socket" # for Socket.gethostname
require "logger"
require "tmpdir"

class FPM::Package
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

  # A identifier representing the vendor. Any string is fine.
  # This is usually who produced the software.
  attr_accessor :vendor

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

  private

  def initialize
    @logger = Logger.new(STDERR)
    @logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

    # Default version is 1.0 in case nobody told us a specific version.
    @version = 1.0
    @epoch = 1
    @dependencies = []
    @iteration = nil
    @url = nil
    @category = "default"
    @license = "unknown"
    @vendor = "none"

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

    # If @architecture is nil, the target package should provide a default.
    # Special 'architecture' values include "all" (aka rpm's noarch, debian's all)
    # Another special includes "native" which will be the current platform's arch.
    @architecture = "all"
    @description = "no description given"

    # TODO(sissel): Implement provides, requires, conflicts, etc later.
    #@provides = []
    #@conflicts = source[:conflicts] || []
    #@scripts = source[:scripts]
    #@config_files = source[:config_files] || []
    #@prefix = source[:prefix] || "/"
  end # def initialize

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
  def <<(input)
    raise NotImplementedError.new
  end # def <<

  # TODO [Jay]: make this better...?
  def type
    self.class.name.split(':').last.downcase
  end # def type

  # Convert this package to a new package type
  def convert(klass)
    pkg = klass.new
    pkg.instance_variable_set(:@staging_path, staging_path)

    # copy other bits
    ivars = [
      :architecture, :attributes, :category, :config_files, :conflicts,
      :dependencies, :description, :epoch, :iteration, :license, :maintainer,
      :name, :provides, :replaces, :scripts, :url, :vendor, :version
    ]
    ivars.each do |ivar|
      pkg.instance_variable_set(ivar, instance_variable_get(ivar))
    end

    return pkg
  end # def convert

  def output(path)
    raise NotImplementedError.new("This must be implemented by FPM::Package subclasses")
  end # def output

  def staging_path
    @staging_path ||= ::Dir.mktmpdir(File.join(::Dir.pwd, "package-#{type}-staging"))
  end # def staging_path

  # Clean up any temporary storage used by this class.
  def cleanup
    FileUtils.rm_r(staging_path)
  end # def cleanup

  public(:type, :initialize, :convert, :output, :<<, :cleanup, :staging_path)
end # class FPM::Package
