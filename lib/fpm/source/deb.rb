require 'fpm/source'
require 'fpm/util'

class FPM::Source::DEB < FPM::Source
  def get_metadata
    @deb = @paths.first
    self[:name]    = %x{dpkg-deb --showformat='${Package}'     -W #{@deb}}.chomp
    self[:summary] = %x{dpkg-deb --showformat='${Description}' -W #{@deb}}.split("\n").first.chomp

    self[:version]      = %x{dpkg-deb --showformat='${Version}' -W #{@deb}}.split('-').first.chomp
    self[:iteration]    = %x{dpkg-deb --showformat='${Version}' -W #{@deb}}.split('-').last.chomp
    self[:dependencies] = %x{dpkg-deb --showformat='${Depends}' -W #{@deb}}.split(', ').collect { |line| line.split }

    @paths = %x{dpkg-deb -c #{@deb}}.split("\n")
  end

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    ::Dir.mkdir(tmpdir)

    # Extract the .deb
    safesystem("dpkg -x #{@deb} #{tmpdir}")
    
    # Construct the tarball
    tar(tar_path, '.', tmpdir)
    @paths = ['.']

    # Compress the tarball
    safesystem(*['gzip', '-f', tar_path])
  end
end
