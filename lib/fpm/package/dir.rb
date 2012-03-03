require "fpm/package"
require "backports"
require "fileutils"
require "find"

class FPM::Package::Dir < FPM::Package
  private

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
  ensure
    @logger.remove("method")
  end # def input

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

    Find.find(source).each do |file|
      next if source == file && File.directory?(file) # ignore the directory itself
      target = File.join(destination, file)
      copy(file, target)
    end
  end # def clone

  def copy(source, destination)
    directory = File.dirname(destination)
    if !File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end

    # Create a directory if this path is a directory
    if File.directory?(source)
      @logger.debug("Creating", :directory => destination)
      FileUtils.mkdir(destination)
    else
      # Otherwise try copying the file.
      @logger.debug("Copying", :source => source, :destination => destination)
      begin
        File.link(source, destination)
      rescue Errno::EXDEV
        # Hardlink attempt failed, copy it instead
        FileUtils.copy(source, destination)
      end
    end
  end # def copy

  public(:input, :output)
end # class FPM::Package::Dir
