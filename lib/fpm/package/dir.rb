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
    @logger.debug("Copying", :input => path)
    @logger["method"] = "input"
    ::Dir.chdir(@attributes[:chdir] || ".") do
      if @attributes[:prefix]
        clone(path, File.join(staging_path, @attributes[:prefix]))
      else
        clone(path, staging_path)
      end
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
  def output(dir)
    dir = File.expand_path(dir)
    ::Dir.chdir(staging_path) do
      @logger["method"] = "output"
      clone(".", dir)
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

    Find.find(source) do |file|
      next if source == file && File.directory?(file) # ignore the directory itself
      target = File.join(destination, file)
      copy(file, target)
    end
  end # def clone

  # Copy, recursively, from source to destination.
  #
  # Files will be hardlinked if possible, but copied otherwise.
  def copy(source, destination)
    directory = File.dirname(destination)
    if !File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end

    # Create a directory if this path is a directory
    if File.directory?(source) and !File.symlink?(source)
      @logger.debug("Creating", :directory => destination)
      FileUtils.mkdir(destination)
    else
      # Otherwise try copying the file.
      begin
        @logger.debug("Linking", :source => source, :destination => destination)
        File.link(source, destination)
      rescue Errno::EXDEV
        # Hardlink attempt failed, copy it instead
        @logger.debug("Copying", :source => source, :destination => destination)
        FileUtils.copy_entry(source, destination)
      end
    end
  end # def copy

  public(:input, :output)
end # class FPM::Package::Dir
