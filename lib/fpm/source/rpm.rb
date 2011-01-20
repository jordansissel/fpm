require "fpm/source"

class FPM::Source::RPM < FPM::Source
  def get_metadata
    self[:name] = %x{rpm -q --qf '%{name}' -p #{@paths.first}}

    self[:version] = %x{rpm -q --qf '%{version}' -p #{@paths.first}}
    self[:iteration] = %x{rpm -q --qf '%{release}' -p #{@paths.first}}
    self[:summary] = %x{rpm -q --qf '%{summary}' -p #{@paths.first}}
    #self[:description] = %x{rpm -q --qf '%{description}' -p #{@paths.first}}
    self[:dependencies] = %x{rpm -qRp #{@paths.first}}.split("\n")\
      .collect { |line| line.strip }

    @rpm = @paths.first
    @paths = %x{rpm -qlp #{@paths.first}}.split("\n")

  end

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    ::Dir.mkdir(tmpdir)
    system("rpm2cpio #{@rpm} | (cd #{tmpdir}; cpio -i --make-directories)")
    tar(tar_path, ".", tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end
end
