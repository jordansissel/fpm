require "fpm/package"
require "backports"
require "fileutils"
require "find"

class FPM::Package::Dir < FPM::Package
  private

  def input(path)
    @paths ||= []
    @paths << path

    clone(path, staging_path)
  end # def input

  def output(dir)
    dir = File.expand_path(dir)
    @paths.each do |path|
      ::Dir.chdir(staging_path) do
        clone(path, dir)
      end
    end
  end

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

    ::Dir.chdir(@attributes[:chdir] || ".") do
      #p :chdir => ::Dir.pwd, :source => source
      Find.find(source).each do |file|
        next if source == file # ignore the directory itself
        # Translate file paths with attributes like 'prefix' and 'chdir'
        if @attributes[:prefix]
          target = File.join(destination, @attributes[:prefix], file)
        else
          target = File.join(destination, file)
        end

        copy(file, target)
      end
    end
  end # def clone

  def copy(source, destination)
    directory = File.dirname(destination)
    if !File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end

    # Create a directory if this path is a directory
    if File.directory?(source)
      FileUtils.mkdir(destination)
    else
      # Otherwise try copying the file.
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
