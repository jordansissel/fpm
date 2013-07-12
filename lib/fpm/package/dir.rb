require "fpm/package"
require "backports"
require "fileutils"
require "find"
require "socket"

# A directory package.
#
# This class supports both input and output. As a note, 'output' will
# only emit the files, not any metadata. This is an effective way
# to extract another package type.
class FPM::Package::Dir < FPM::Package
  private

  # Add a new path to this package.
  #
  # A special handling of the path occurs if it includes a '=' symbol.
  # You can say "source=destination" and it will copy files from that source
  # to the given destination in the package.
  #
  # This lets you take a local directory and map it to the desired location at
  # packaging time. Such as: "./src/redis-server=/usr/local/bin" will make
  # the local file ./src/redis-server appear as /usr/local/bin/redis-server in
  # your package.
  #
  # If the path is a directory, it is copied recursively. The behavior
  # of the copying is modified by the :chdir and :prefix attributes.
  #
  # If :prefix is set, the destination path is prefixed with that value.
  # If :chdir is set, the current directory is changed to that value
  # during the copy.
  #
  # Example: Copy /etc/X11 into this package as /opt/xorg/X11:
  #
  #     package.attributes[:prefix] = "/opt/xorg"
  #     package.attributes[:chdir] = "/etc"
  #     package.input("X11")
  def input(path)
    chdir = attributes[:chdir] || "."

    # Support mapping source=dest
    if path =~ /.=./
      origin, destination = path.split("=", 2)

      # file -> directory
      #   ./some/file=/usr/local should result in /usr/local/file
      # directory -> directory
      #   ./some=/usr/local should result in /usr/local/...
      #   if ./some/file, then /usr/local/file
      if File.directory?(origin)
        chdir = origin
        source = "."
      else
        chdir = File.dirname(origin)
        source = File.basename(origin)
      end
    else
      source, destination = path, "/"
    end

    if attributes[:prefix]
      destination = File.join(attributes[:prefix], destination)
    end

    destination = File.join(staging_path, destination)

    @logger["method"] = "input"
    @logger.debug("Copying", :input => source, :output => destination)
    ::Dir.chdir(chdir) do
      clone(source, destination)
    end

    # Set some defaults. This is useful because other package types
    # can include license data from themselves (rpms, gems, etc),
    # but to make sure a simple dir -> rpm works without having
    # to specify a license.
    self.license = "unknown"
    self.vendor = [ENV["USER"], Socket.gethostname].join("@")
  ensure
    # Clean up any logger context we added.
    @logger.remove("method")
  end # def input

  # Output this package to the given directory.
  def output(output_path)
    output_check(output_path)

    output_path = File.expand_path(output_path)
    ::Dir.chdir(staging_path) do
      @logger["method"] = "output"
      clone(".", output_path)
    end
  ensure
    @logger.remove("method")
  end # def output

  private
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
    # Copy all files from 'path' into staging_path
    #p :clone => { source => destination } 
    Find.find(source) do |path|
      target = File.join(destination, path)
      copy(path, target)
    end
  end # def clone

  # Copy a path.
  #
  # Files will be hardlinked if possible, but copied otherwise.
  # Symlinks should be copied as symlinks.
  def copy(source, destination)
    directory = File.dirname(destination)
    if !File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end

    if File.directory?(source)
      if !File.symlink?(source)
        # Create a directory if this path is a directory
        @logger.debug("Creating", :directory => destination)
        if !File.directory?(destination)
          FileUtils.mkdir(destination)
        end
      else
        # Linking symlinked directories causes a hardlink to be created, which
        # results in the source directory being wiped out during cleanup,
        # so copy the symlink.
        @logger.debug("Copying symlinked directory", :source => source,
                      :destination => destination)
        FileUtils.copy_entry(source, destination)
      end
    else
      # Otherwise try copying the file.
      begin
        @logger.debug("Linking", :source => source, :destination => destination)
        File.link(source, destination)
      rescue Errno::ENOENT, Errno::EXDEV, Errno::EPERM
        # Hardlink attempt failed, copy it instead
        @logger.debug("Copying", :source => source, :destination => destination)
        FileUtils.copy_entry(source, destination)
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

  public(:input, :output)
end # class FPM::Package::Dir
