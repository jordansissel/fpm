require "fpm/namespace"
require "socket" # for Socket.gethostname

class FPM::Package 
  # The name of this package
  attr_accessor :name

  # The version of this package (the upstream version)
  attr_accessor :version

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
  
  def initialize
    @iteration = 1
    @url = ""
    @category = "default"
    @license = "unknown"
    @maintainer = "<#{ENV["USER"]}@#{Socket.gethostname}>"
    @architecture = nil

    # Garbage is stuff you may want to clean up.
    @garbage = []
  end

  def tar(output, paths)
    dirs = []
    paths.each do |path|
      while path != "/" and path != "."
        dirs << path if !dirs.include?(path) 
        path = File.dirname(path)
      end
    end # paths.each
    dirs = dirs.sort { |a,b| a.length <=> b.length}
    system(*["tar", "--owner=root", "--group=root", "-cf", output, "--no-recursion", *dirs])
    system(*["tar", "--owner=root", "--group=root", "-rf", output, *paths])
  end

end
