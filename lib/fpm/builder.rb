require 'fileutils'
class FPM::Builder
  # where is the package's root?
  def root
    @root ||= (@source.root || '.')
  end

  # where the package goes
  def output
    @output ||= begin
      o = @package.default_output
      if o.start_with? '/'
        o
      else 
        File.join(@working_dir, o)
      end
    end
  end

  # things to clean up afterwards
  def garbage
    @garbage ||= []
  end

  attr_reader :paths
  attr_reader :package
  attr_reader :source

  def initialize(settings, paths=[])
    @working_dir = Dir.pwd
    root = settings.chdir || '.'
    paths = ['.'] if paths.empty?
    @source  = source_class_for(settings.source_type || 'dir').new(
      paths, root,
      :version => settings.version,
      :name => settings.package_name,
      :prefix => settings.prefix
    )

    @paths = paths
    @package = package_class_for(settings.package_type).new(@source)
    # Append dependencies given from settings (-d flag for fpm)
    @package.dependencies += settings.dependencies if settings.dependencies

    @output = settings.package_path
    @recurse_dependencies = settings.recurse_dependencies
  end # def initialize
  
  def tar_path
    @tar_path ||= "#{builddir}/data.tar"
  end

  # Assemble the package
  def assemble!
    output.gsub!(/VERSION/, "#{@source[:version]}-#{@package.iteration}")
    output.gsub!(/ARCH/, @package.architecture)

    File.delete(output) if File.exists?(output) && !File.directory?(output)

    make_builddir!

    ::Dir.chdir root do
      @source.make_tarball!(tar_path, builddir)

      generate_md5sums
      generate_specfile
    end

    ::Dir.chdir(builddir) do
      @package.build!({
        :tarball => tar_path,
        :output => output
      })
    end

    cleanup!

  end # def assemble!

  private
  def builddir
    @builddir ||= File.expand_path(
      "#{Dir.pwd}/build-#{@package.type}-#{File.basename(output)}"
    )
  end

  private
  def make_builddir!
    FileUtils.rm_rf builddir
    garbage << builddir
    FileUtils.mkdir(builddir) if !File.directory?(builddir)
  end

  # TODO: [Jay] make this better.
  private
  def package_class_for(type)
    type = FPM::Target::constants.find { |c| c.downcase.to_s == type }
    if !type
      raise ArgumentError, "unknown package type #{type.inspect}"
    end

    return FPM::Target.const_get(type)
  end

  # TODO: [Jay] make this better.
  private
  def source_class_for(type)
    type = FPM::Source::constants.find { |c| c.downcase.to_s == type }
    if !type
      raise ArgumentError, "unknown package type #{type.inspect}"
    end

    return FPM::Source.const_get(type)
  end

  private
  def cleanup!
    return [] if garbage.empty?
    FileUtils.rm_rf(garbage) && garbage.clear
  end

  private
  def generate_specfile
    File.open(@package.specfile(builddir), "w") do |f|
      f.puts @package.render_spec
    end
  end

  private
  def generate_md5sums
    md5sums = checksum(paths)
    File.open("#{builddir}/md5sums", "w") { |f| f.puts md5sums }
    md5sums
  end

  private
  def checksum(paths)
    md5sums = []
    paths.each do |path|
      md5sums += %x{find #{path} -type f -print0 | xargs -0 md5sum}.split("\n")
    end
  end # def checksum
end
