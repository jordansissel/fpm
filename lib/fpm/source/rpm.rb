require "fpm/source"

class FPM::Source::RPM < FPM::Source
  def get_metadata
    self[:name] = File.basename(File.expand_path(root))
  end

  def make_tarball!(tar_path)
    tmpdir = "#{tar_path}.dir"
    ::Dir.mkdir(tmpdir)
    system("rpm2cpio #{@paths.first} | (cd #{tmpdir}; cpio -i --make-directories)")
    tar(tar_path, ".", tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end
end
