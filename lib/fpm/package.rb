require "fpm/namespace"
require "socket" # for Socket.gethostname
require "logger"
require "find" # for Find.find (directory walking)

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
  # If left unpicked, it defaults to 1.
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

  # Package path prefix
  attr_accessor :prefix

	# target-specific settings
	attr_accessor :settings

  def initialize(source, params={})
    @source = source
    @logger = Logger.new(STDERR)
    @logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

    @name = source[:name] # || fail

    # Default version is 1.0 in case nobody told us a specific version.
    @version = source[:version] || "1.0"
    @epoch = source[:epoch]

    @dependencies = source[:dependencies] || []
    # Iteration can be nil. If nil, the fpm package implementation is expected
    # to handle any default value that should be instead.
    @iteration = source[:iteration]
    @url = source[:url] || "http://nourlgiven.example.com/no/url/given"
    @category = source[:category] || "default"
    @license = source[:license] || "unknown"
    @vendor = source[:vendor] || "none"
    #@maintainer = source[:maintainer] || "<#{ENV["USER"]}@#{Socket.gethostname}>"
    @maintainer = source[:maintainer]

    # Default maintainer if none given.
    if @maintainer.nil? or @maintainer.empty?
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
    end

    # If @architecture is nil, the target package should provide a default.
    # Special 'architecture' values include "all" (aka rpm's noarch, debian's all)
    # Another special includes "native" which will be the current platform's arch.
    @architecture = source[:architecture]
    @description = source[:description] || "no description given"
    @provides = source[:provides] || []
    @replaces = source[:replaces] || []
    @conflicts = source[:conflicts] || []
    @scripts = source[:scripts]
    @config_files = source[:config_files] || []
    @prefix = source[:prefix] || "/"

    # Target-specific settings, mirrors :settings metadata in FPM::Source
    @settings = params[:settings] || {}
  end # def initialize

  # nobody needs md5sums by default.
  def needs_md5sums
    false
  end # def needs_md5sums

  # TODO [Jay]: make this better...?
  def type
    self.class.name.split(':').last.downcase
  end # def type

  def template(path=nil)
    path ||= "#{type}.erb"
    @logger.info("Reading template: #{path}")
    tpl = File.read("#{FPM::DIRS[:templates]}/#{path}")
    return ERB.new(tpl, nil, "-")
  end # def template

  def render_spec
    # find all files in paths given.
    paths = []
    @source.paths.each do |path|
      Find.find(path) { |p| paths << p }
    end
    #@logger.info(:paths => paths.sort)
    template.result(binding)
  end # def render_spec

  # Default specfile generator just makes one specfile, whatever that is for
  # this package.
  def generate_specfile(builddir)
    File.open(specfile(builddir), "w") do |f|
      f.puts render_spec
    end
  end # def generate_specfile

  def default_output
    if iteration
      "#{name}-#{version}-#{iteration}.#{architecture}.#{type}"
    else
      "#{name}-#{version}.#{architecture}.#{type}"
    end
  end # def default_output

  def fixpath(path)
    if path[0,1] != "/"
      path = File.join(@source.root, path)
    end
    return path if File.symlink?(path)
    @logger.info(:fixpath => path)
    realpath = Pathname.new(path).realpath.to_s
    re = Regexp.new("^#{Regexp.escape(@source.root)}")
    realpath.gsub!(re, "")
    @logger.info(:fixpath_result => realpath)
    return realpath
  end # def fixpath
end # class FPM::Package
