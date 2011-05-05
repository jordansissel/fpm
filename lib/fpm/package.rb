require "fpm/namespace"
require "socket" # for Socket.gethostname

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

  # a summary or description of the package
  attr_accessor :description

  # hash of paths for maintainer/package scripts (postinstall, etc)
  attr_accessor :scripts

  def initialize(source)
    @source = source

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
    @maintainer = source[:maintainer] || "<#{ENV["USER"]}@#{Socket.gethostname}>"
    @architecture = source[:architecture] || %x{uname -m}.chomp
    @description = source[:description] || "no description given"
    @provides = source[:provides] || []
    @scripts = source[:scripts]
  end # def initialize

  def generate_specfile(builddir, paths)
    spec = template.result(binding)
    File.open(specfile(builddir), "w") { |f| f.puts spec }
  end # def generate_specfile

  def generate_md5sums(builddir, paths)
    md5sums = self.checksum(paths)
    File.open("#{builddir}/md5sums", "w") { |f| f.puts md5sums }
    md5sums
  end # def generate_md5sums

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
    template.result(binding)
  end # def render_spec

  def default_output
    if iteration
      "#{name}-#{version}-#{iteration}.#{architecture}.#{type}"
    else
      "#{name}-#{version}.#{architecture}.#{type}"
    end
  end # def default_output
end
