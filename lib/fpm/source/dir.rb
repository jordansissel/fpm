require "fpm/source"
require "fileutils"

class FPM::Source::Dir < FPM::Source
  def get_metadata
    self[:name] = File.basename(File.expand_path(root))
  end

  def make_tarball!(tar_path, builddir)
    if self[:prefix]
      # Trim leading '/' from prefix
      self[:prefix] = self[:prefix][1..-1] if self[:prefix] =~ /^\//

      # Prefix all files with a path if given.
      @paths.each do |path|
        # Trim @root (--chdir)
        path = path[@root.size .. -1] if path.start_with?(@root)

        # Copy to self[:prefix] (aka --prefix)
        if File.directory?(path)
          dest = "#{builddir}/tarbuild/#{self[:prefix]}/#{path}"
        else
          dest = "#{builddir}/tarbuild/#{self[:prefix]}/#{File.dirname(path)}"
        end

        ::FileUtils.mkdir_p(dest)
        rsync = ["rsync", "-a", path, dest]
        p rsync
        system(*rsync)

        # FileUtils.cp_r is pretty silly about how it copies files in some
        # cases (funky permissions, etc)
        # Use rsync instead..
        #FileUtils.cp_r(path, dest)
      end

      # Prefix paths with 'prefix' if necessary.
      if self[:prefix]
        @paths = @paths.collect { |p| File.join("/", self[:prefix], p) }
      end

      ::Dir.chdir("#{builddir}/tarbuild") do
        system("ls #{builddir}/tarbuild")
        tar(tar_path, ".")
      end
    else
      tar(tar_path, paths)
    end

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end # def make_tarball!
end # class FPM::Source::Dir
