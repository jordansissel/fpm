require "fpm/package"
require "fpm/util"
require "backports"
require "fileutils"
require "find"
require "socket"

# A virtualenv package.
class FPM::Package::VirtualEnv < FPM::Package
    option "--installation-path", "DIRECTORY", "The directory to install the final environment."

    def input(path)
        raise ArgumentError, "Parameter --virtualenv-installation-path is mandatory." if attributes[:virtualenv_installation_path].nil?

        dest_path = attributes[:virtualenv_installation_path]
        path = File.expand_path path
        venv = get_virtualenv path
        build_folder = "build_#{Time.now.to_i}"

        raise ArgumentError, "Path '#{path}' does not contain a valid virtualenv." if venv.nil?

        root_folder = "#{build_folder}#{File.dirname dest_path}"
        final_folder = "#{build_folder}#{dest_path}"

        logger.info( "Creating temporary build folder #{build_folder} ..." )

        # copy the python project into a temporary one
        FileUtils.mkdir_p root_folder
        FileUtils.cp_r path, final_folder

        logger.info( "Updating virtualenv paths ..." )

        # update the virtualenv to point to the installation folder
        venv = get_virtualenv "#{final_folder}"
        ::Dir.chdir(venv) do
            safesystem( "virtualenv-tools --update-path #{dest_path}" )
        end

        # remove precompiled python files
        remove_python_compiled_files final_folder

        path = '.'
        chdir = build_folder
        source = path
        destination = "/"

        if attributes[:prefix]
          destination = File.join(attributes[:prefix], destination)
        end

        destination = File.join(staging_path, destination)

        logger.info( "Creating source '#{destination}' ..." )

        logger["method"] = "input"
        begin
          ::Dir.chdir(chdir) do
            begin
              clone(source, destination)
            rescue Errno::ENOENT => e
              raise FPM::InvalidPackageConfiguration,
                "Cannot package the path '#{File.join(chdir, source)}', does it exist?"
            end
          end
        rescue Errno::ENOENT => e
          raise FPM::InvalidPackageConfiguration,
            "Cannot chdir to '#{chdir}'. Does it exist?"
        end

        # Set some defaults. This is useful because other package types
        # can include license data from themselves (rpms, gems, etc),
        # but to make sure a simple dir -> rpm works without having
        # to specify a license.
        self.license = "unknown"
        self.vendor = [ENV["USER"], Socket.gethostname].join("@")
    ensure
      # Clean up any logger context we added.
      logger.remove("method")
      # remove the temporary build folder
      FileUtils.rm_rf build_folder
    end

private

    # Delete python precompiled files found in a given folder.
    def remove_python_compiled_files path
        Find.find(path) do |path|
            if path.end_with?'.pyc' or path.end_with?'.pyo'
                FileUtils.rm path
            end
        end
    end

    # Find the virtualenv installation inside a given path.
    def get_virtualenv path
        venv = nil
        ::Dir["#{path}/*"].each do |file|
            if File.directory?(file) and File.exist?( "#{file}/bin/activate" )
                venv = file
                break
            end
        end
        venv
    end

    # Copy a file or directory to a destination
    #
    # This is special because it respects the full path of the source.
    # Aditionally, hardlinks will be used instead of copies.
    #
    # Example:
    #
    #     clone("/tmp/hello/world", "/tmp/example")
    #
    # The above will copy, recursively, /tmp/hello/world into
    # /tmp/example/hello/world
    def clone(source, destination)
      logger.debug("Cloning path", :source => source, :destination => destination)
      # Edge case check; abort if the temporary directory is the source.
      # If the temporary dir is the same path as the source, it causes
      # fpm to recursively (and forever) copy the staging directory by
      # accident (#542).
      if File.expand_path(source) == File.expand_path(::Dir.tmpdir)
        raise FPM::InvalidPackageConfiguration,
          "A source directory cannot be the root of your temporary " \
          "directory (#{::Dir.tmpdir}). fpm uses the temporary directory " \
          "to stage files during packaging, so this setting would have " \
          "caused fpm to loop creating staging directories and copying " \
          "them into your package! Oops! If you are confused, maybe you could " \
          "check your TMPDIR or TEMPDIR environment variables?"
      end

      # For single file copies, permit file destinations
      fileinfo = File.lstat(source)
      if fileinfo.file? && !File.directory?(destination)
        if destination[-1,1] == "/"
          copy(source, File.join(destination, source))
        else
          copy(source, destination)
        end
      elsif fileinfo.symlink?
        copy(source, File.join(destination, source))
      else
        # Copy all files from 'path' into staging_path
        Find.find(source) do |path|
          target = File.join(destination, path)
          copy(path, target)
        end
      end
    end # def clone

    # Copy a path.
    #
    # Files will be hardlinked if possible, but copied otherwise.
    # Symlinks should be copied as symlinks.
    def copy(source, destination)
      logger.debug("Copying path", :source => source, :destination => destination)
      directory = File.dirname(destination)
      if !File.directory?(directory)
        FileUtils.mkdir_p(directory)
      end

      if File.directory?(source)
        if !File.symlink?(source)
          # Create a directory if this path is a directory
          logger.debug("Creating", :directory => destination)
          if !File.directory?(destination)
            FileUtils.mkdir(destination)
          end
        else
          # Linking symlinked directories causes a hardlink to be created, which
          # results in the source directory being wiped out during cleanup,
          # so copy the symlink.
          logger.debug("Copying symlinked directory", :source => source,
                        :destination => destination)
          FileUtils.copy_entry(source, destination)
        end
      else
        # Otherwise try copying the file.
        begin
          logger.debug("Linking", :source => source, :destination => destination)
          File.link(source, destination)
        rescue Errno::ENOENT, Errno::EXDEV, Errno::EPERM
          # Hardlink attempt failed, copy it instead
          logger.debug("Copying", :source => source, :destination => destination)
          copy_entry(source, destination)
        rescue Errno::EEXIST
          sane_path = destination.gsub(staging_path, "")
          logger.error("Cannot copy file, the destination path is probably a directory and I attempted to write a file.", :path => sane_path, :staging => staging_path)
        end
      end

      copy_metadata(source, destination)
    end # def copy

    def copy_metadata(source, destination)
      source_stat = File::lstat(source)
      dest_stat = File::lstat(destination)

      # If this is a hard-link, there's no metadata to copy.
      # If this is a symlink, what it points to hasn't been copied yet.
      return if source_stat.ino == dest_stat.ino || dest_stat.symlink?

      File.utime(source_stat.atime, source_stat.mtime, destination)
      mode = source_stat.mode
      begin
        File.lchown(source_stat.uid, source_stat.gid, destination)
      rescue Errno::EPERM
        # clear setuid/setgid
        mode &= 01777
      end

      unless source_stat.symlink?
        File.chmod(mode, destination)
      end
    end # def copy_metadata
end
