require "fpm/source"

class FPM::Source::RPM < FPM::Source
  def get_metadata
    @rpm = @paths.first
    self[:name] = %x{rpm -q --qf '%{name}' -p #{@rpm}}

    self[:version] = %x{rpm -q --qf '%{version}' -p #{@rpm}}
    self[:iteration] = %x{rpm -q --qf '%{release}' -p #{@rpm}}
    self[:summary] = %x{rpm -q --qf '%{summary}' -p #{@rpm}}
    #self[:description] = %x{rpm -q --qf '%{description}' -p #{@rpm}}
    self[:dependencies] = %x{rpm -qRp #{@rpm}}.split("\n")\
      .collect { |line| line.strip }

    @paths = %x{rpm -qlp #{@rpm}}.split("\n")
  end

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    ::Dir.mkdir(tmpdir)
    system("rpm2cpio #{@rpm} | (cd #{tmpdir}; cpio -i --make-directories)")
    tar(tar_path, ".", tmpdir)
    @paths = "."
    @root = tmpdir

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end
end
