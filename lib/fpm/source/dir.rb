require "fpm/source"

class FPM::Source::Dir < FPM::Source
  def get_metadata
    self[:name] = File.basename(File.expand_path(root))
  end

  def make_tarball!(tar_path)
    tar(tar_path, paths)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end
end
