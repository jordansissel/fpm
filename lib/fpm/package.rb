require "fpm/namespace"
require "socket" # for Socket.gethostname
require "logger"

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

  # What architecture is this package for?
  attr_accessor :architecture

  # Array of dependencies.
  attr_accessor :dependencies

  # Array of things this package provides.
  # (Not all packages support this)
  attr_accessor :provides

  # Array of things this package replaces.
  # (Not all packages support this)
  attr_accessor :replaces

  # a summary or description of the package
  attr_accessor :description

  # hash of paths for maintainer/package scripts (postinstall, etc)
  attr_accessor :scripts

  def initialize(source)
    @source = source
    @logger = Logger.new(STDERR)

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
    @scripts = source[:scripts]
  end # def initialize

  # TODO(sissel): not needed anymore
  #def generate_specfile(builddir, paths)
    #spec = template.result(binding)
    #File.open(specfile(builddir), "w") { |f| f.puts spec }
  #end # def generate_specfile

  # nobody needs md5sums by default.
  def needs_md5sums
    false
  end # def needs_md5sums

  #def generate_md5sums(builddir, paths)
    #md5sums = self.checksum(paths)
    #File.open("#{builddir}/md5sums", "w") { |f| f.puts md5sums }
    #md5sums
  #end # def generate_md5sums

  # TODO [Jay]: make this better...?
  def type
    self.class.name.split(':').last.downcase
  end # def type

  def template
    @template ||= begin
      tpl = File.read(
        "#{FPM::DIRS[:templates]}/#{type}.erb"
      )
      ERB.new(tpl, nil, "<>")
    end
  end # def template

  def render_spec
    # find all files in paths given.
    paths = []
    @source.paths.each do |path|
      entries = Dir.new(path).to_a
      entries.each do |entry|
        if File.directory?(entry)

      end
    end
    template.result(binding)
  end # def render_spec

  def default_output
    if iteration
      "#{name}-#{version}-#{iteration}.#{architecture}.#{type}"
    else
      "#{name}-#{version}.#{architecture}.#{type}"
    end
  end # def default_output
end # class FPM::Package
