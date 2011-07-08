require "fileutils"
require "pathname"

class FPM::Builder
  # where is the package's root?
  def root
    @root ||= (@source.root || '.')
  end

  # where the package goes
  def output
    @output ||= begin
      o = @package.default_output
      if o[0,1] == "/"
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
    @logger = Logger.new(STDERR)
    @logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

    @working_dir = Dir.pwd
    root = settings.chdir || '.'
    paths = ['.'] if paths.empty?
    @source  = source_class_for(settings.source_type || 'dir').new(
      paths, root,
      :version => settings.version,
      :iteration => settings.iteration,
      :epoch => settings.epoch,
      :name => settings.package_name,
      :prefix => settings.prefix,
      :suffix => settings.suffix,
      :exclude => settings.exclude,
      :maintainer => settings.maintainer,
      :provides => [],
      :replaces => [],
      :conflicts => [],
      :description => settings.description,
      :url => settings.url,
      :settings => settings.source
    )

    @edit = !!settings.edit

    @paths = paths
    @package = package_class_for(settings.package_type).new(@source,
			:settings => settings.target
		)
    # Append dependencies given from settings (-d flag for fpm)
    @package.dependencies += settings.dependencies if settings.dependencies
    # Append provides given from settings (--provides flag for fpm)
    @package.provides += settings.provides if settings.provides
    @package.replaces += settings.replaces if settings.replaces
    @package.conflicts += settings.conflicts if settings.conflicts
    @package.architecture = settings.architecture if settings.architecture
    @package.category = settings.category if settings.category
    @package.scripts = settings.scripts
    @package.config_files = settings.config_files

    @output = settings.package_path
    @recurse_dependencies = settings.recurse_dependencies
  end # def initialize

  def tar_path
    @tar_path ||= "#{builddir}/data.tar"
  end

  # Assemble the package
  def assemble!
    version_a = [ @source[:version], @package.iteration ].compact
    if @package.epoch
      output.gsub!(/VERSION/, "#{@package.epoch}:" + version_a.join('-'))
    else
      output.gsub!(/VERSION/, version_a.join('-'))
    end
    output.gsub!(/ARCH/, @package.architecture)

    File.delete(output) if File.exists?(output) && !File.directory?(output)

    make_builddir!

    ::Dir.chdir root do
      @source.make_tarball!(tar_path, builddir)

      # Hack to unpack before generating the spec, etc.
      # Need to formalize this feature.
      # Perhaps something like @package.prepare
      if @package.respond_to?(:unpack_data_to)
        data_tarball = File.join(builddir, "data.tar.gz")
        Dir.chdir(builddir) do
          FileUtils.mkdir_p(@package.unpack_data_to)
          system("gzip -d #{data_tarball}")
          Dir.chdir(@package.unpack_data_to) do
            @source.root = Dir.pwd
            system("tar -xf #{data_tarball.gsub(/\.gz$/, "")}")
          end
        end
      end

      generate_md5sums if @package.needs_md5sums
      generate_specfile
      edit_specfile if @edit
    end

    ::Dir.chdir(builddir) do
      @package.build!({
        :tarball => tar_path,
        :output => output
      })
    end

    garbage << @source.garbage if @source.respond_to?(:garbage)

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
    realtype = FPM::Target.constants.find { |c| c.downcase.to_s == type }
    if !realtype
      valid_types = FPM::Target.constants.collect { |c| c.downcase }
      @logger.fatal("No such package target type #{type.inspect}; " \
                    "Valid types: #{valid_types.join(", ")}")
      raise ArgumentError, "unknown package type #{type.inspect}"
    end

    return FPM::Target.const_get(realtype)
  end

  # TODO: [Jay] make this better.
  private
  def source_class_for(type)
    realtype = FPM::Source::constants.find { |c| c.downcase.to_s == type }
    if !realtype
      valid_types = FPM::Source.constants.collect { |c| c.downcase }
      @logger.fatal("No such package source type #{type.inspect}; " \
                    "Valid types: #{valid_types.join(", ")}")
      raise ArgumentError, "unknown package type #{type.inspect}"
    end

    return FPM::Source.const_get(realtype)
  end

  private
  def cleanup!
    return [] if garbage.empty?
    FileUtils.rm_rf(garbage) && garbage.clear
  end

  private
  def generate_specfile
    @package.generate_specfile(builddir)
  end

  private
  def edit_specfile
    # TODO(sissel): support editing multiple files for targets like
    # puppet which generate multiple manifests.
    editor = ENV['FPM_EDITOR'] || ENV['EDITOR'] || 'vi'
    system("#{editor} '#{package.specfile(builddir)}'")
    unless File.size? package.specfile(builddir)
      puts "Empty specfile.  Aborting."
      exit 1
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
      next if !File.exists?(path)
      md5sums += %x{find #{path} -type f -print0 | xargs -0 md5sum}.split("\n")
    end
  end # def checksum
end
