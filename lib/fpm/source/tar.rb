require "fpm/source"
require "fileutils"
require "fpm/rubyfixes"

class FPM::Source::Tar < FPM::Source
  def get_metadata
    self[:name] = @paths.first.split(".").first
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    input_tarball = @paths.first

    if input_tarball =~ /\.tar\.bz2$/
      compression = :bipz2
    elsif input_tarball =~ /\.tar\.gz$/
      compression = :gzip
    elsif input_tarball =~ /\.tar\.xz$/
      compression = :lzma
    else
      compression = :none
    end

    # Unpack the tar file
    installdir = "#{builddir}/tarbuild/#{self[:prefix]}"
    FileUtils.mkdir_p(installdir)
    flags = "-xf #{input_tarball} -C #{installdir}"
    case compression
      when :bzip2; flags += " -j"
      when :gzip; flags += " -z"
      when :lzma; flags += " --lzma"
    end
    #puts("tar #{flags}")
    #sleep 5
    system("tar #{flags}")

    if self[:prefix]
      @paths = [self[:prefix]]
    else
      @paths = ["."]
    end

    ::Dir.chdir("#{builddir}/tarbuild") do
      tar(tar_path, ".")
    end

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end # def make_tarball!
end # class FPM::Source::Dir
