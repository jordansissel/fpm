require "backports" # gem backports
require "fpm/package"
require "fpm/util"
require "fileutils"
require "fpm/package/dir"

class FPM::Package::Tar < FPM::Package
  def input(input_path)
    # use part of the filename as the package name
    self.name = File.basename(input_path).split(".").first

    # Unpack the tarball to the build path before ultimately moving it to
    # staging.
    args = ["-xf", input_path, "-C", build_path]

    # Add the tar compression flag if necessary
    with(tar_compression_flag(input_path)) do |flag|
      args << flag unless flag.nil?
    end

    safesystem("tar", *args)

    # use dir to set stuff up properly, mainly so I don't have to reimplement
    # the chdir/prefix stuff special for tar.
    dir = convert(FPM::Package::Dir)
    if attributes[:chdir]
      dir.attributes[:chdir] = File.join(build_path, attributes[:chdir])
    else
      dir.attributes[:chdir] = build_path
    end

    cleanup_staging
    # Tell 'dir' to input "." and chdir/prefix will help it figure out the
    # rest.
    dir.input(".")
    @staging_path = dir.staging_path
    dir.cleanup_build
  end # def input

  def output(output_path)
    # Unpack the tarball to the staging path
    args = ["-cf", output_path, "-C", staging_path, "."]
    with(tar_compression_flag(output_path)) do |flag|
      args << flag unless flag.nil?
    end

    safesystem("tar", *args)
  end # def output

  def tar_compression_flag(path)
    case path
      when /\.tar\.bz2$/
        return "-j"
      when /\.tar\.gz$|\.tgz$/
        return "-z"
      when /\.tar\.xz$/
        return "-J"
      else
        return nil
    end
  end # def tar_compression_flag
end # class FPM::Package::Tar
