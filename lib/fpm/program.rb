require "rubygems"
require "erb" # TODO(sissel): Move to the class that needs it.
require "fpm/namespace"
require "optparse"
require "ostruct"

require "fpm"
require "fpm/flags"

class FPM::Program
  def initialize
    @settings = OpenStruct.new
    @settings.dependencies = []
    @settings.exclude = []  # Paths to exclude in packaging
    @settings.provides = []
    @settings.replaces = []
    @settings.source = {}   # source settings
    @settings.target = {}   # target settings

    # Maintainer scripts - https://github.com/jordansissel/fpm/issues/18
    @settings.scripts ||= {}

    @help = nil
  end # def initialize

  def run(args)
    $: << File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
    paths = options(args)

    ok = true
    if @settings.package_type.nil?
      $stderr.puts "Missing package target type (no -t flag?)"
      ok = false
    end

    if @settings.source_type.nil?
      $stderr.puts "Missing package source type (no -s flag?)"
      ok = false
    end

    if !ok
      $stderr.puts "There were errors; see above."
      $stderr.puts
      $stderr.puts @help
      return 1
    end

    builder = FPM::Builder.new(@settings, paths)
    builder.assemble!
    puts "Created #{builder.output}"
    return 0
  end # def run

  def options(args)
    opts = OptionParser.new
    default_options(opts)

    # Add extra flags from plugins
    FPM::Source::Gem.flags(FPM::Flags.new(opts, "gem", "gem source only"), @settings)
    FPM::Source::Python.flags(FPM::Flags.new(opts, "python", "python source only"),
                              @settings)
    FPM::Target::Deb.flags(FPM::Flags.new(opts, "deb", "deb target only"), @settings)

    # Process fpmrc first
    fpmrc(opts)

    # Proces normal flags now.
    remaining = opts.parse(args)

    # need to print help in a different scope
    @help = opts.help

    return remaining
  end # def options

  def fpmrc(options)
    # Skip if we have no HOME environment variable.
    return if !ENV.include?("HOME")
    rcpath = File.expand_path("~/.fpmrc")
    return if !File.exists?(rcpath)

    # fpmrc exists, read it as flags, one per line.
    File.new(rcpath, "r").each do |line|
      flag = line.chomp
      begin
        options.parse([flag])
      rescue => e
        $stderr.puts "Error parsing fpmrc (#{rcpath})"
        raise e
      end # begin
    end # File.new
  end # def fpmrc

  def default_options(opts)
    # TODO(sissel): Maybe this should be '-o OUTPUT' ?
    opts.on("-p PACKAGEFILE", "--package PACKAGEFILE",
            "The package file to manage") do |path|
      if path =~ /^\//
        @settings.package_path = path
      else
        @settings.package_path = "#{Dir.pwd}/#{path}"
      end
    end # --package

    opts.on("-n PACKAGENAME", "--name PACKAGENAME",
            "What name to give to the package") do |name|
      @settings.package_name = name
    end # --name

    opts.on("-v VERSION", "--version VERSION",
            "version to give the package") do |version|
      @settings.version = version
    end # --version

    opts.on("--iteration ITERATION",
            "(optional) Set the iteration value for this package.") do |iteration|
      @settings.iteration = iteration
    end # --iteration

    opts.on("--epoch EPOCH",
            "(optional) Set epoch value for this package.") do |epoch|
      @settings.epoch = epoch
    end # --epoch

    opts.on("-d DEPENDENCY", "--depends DEPENDENCY") do |dep|
      @settings.dependencies << dep
    end # --depends

    opts.on("--provides PROVIDES") do |thing|
      @settings.provides << thing
    end # --provides

    opts.on("--replaces REPLACES") do |thing|
      @settings.replaces << thing
    end # --replaces

    opts.on("-a ARCHITECTURE", "--architecture ARCHITECTURE") do |arch|
      @settings.architecture = arch
    end # --architecture

    opts.on("-m MAINTAINER", "--maintainer MAINTAINER") do |maintainer|
      @settings.maintainer = maintainer
    end # --maintainer

    opts.on("-C DIRECTORY", "Change directory before searching for files") do |dir|
      @settings.chdir = dir
    end # -C

    opts.on("-t PACKAGE_TYPE", "the type of package you want to create") do |type|
      @settings.package_type = type
    end # -t

    opts.on("-s SOURCE_TYPE", "what to build the package from") do |st|
      @settings.source_type = st
    end # -s

    opts.on("-S PACKAGE_SUFFIX", "which suffix to append to package and dependencies") do |sfx|
      @settings.suffix = sfx
    end # -S

    opts.on("--prefix PREFIX",
            "A path to prefix files with when building the target package. This may not be necessary for all source types. For example, the 'gem' type will prefix with your gem directory (gem env | grep -A1 PATHS:)") do |prefix|
      @settings.prefix = prefix
    end # --prefix

    opts.on("-e", "--edit", "Edit the specfile before building") do
      @settings.edit = true
    end # --edit

    opts.on("-x PATTERN", "--exclude PATTERN",
            "Exclude paths matching pattern (according to tar --exclude)") do |pattern|
      @settings.exclude << pattern
    end # -x / --exclude

    opts.on("--post-install SCRIPTPATH",
            "Add a post-install action. This script will be included in the" \
            " resulting package") do |path|
      @settings.scripts["post-install"] = File.expand_path(path)
    end # --post-install

    opts.on("--pre-install SCRIPTPATH",
            "Add a pre-install action. This script will be included in the" \
            " resulting package") do |path|
      @settings.scripts["pre-install"] = File.expand_path(path)
    end # --pre-install

    opts.on("--pre-uninstall SCRIPTPATH",
            "Add a pre-uninstall action. This script will be included in the" \
            " resulting package") do |path|
      @settings.scripts["pre-uninstall"] = File.expand_path(path)
    end # --pre-uninstall

    opts.on("--post-uninstall SCRIPTPATH",
            "Add a post-uninstall action. This script will be included in the" \
            " resulting package") do |path|
      @settings.scripts["post-uninstall"] = File.expand_path(path)
    end # --post-uninstall

    opts.on("--description DESCRIPTION",
            "Add a description for this package.") do |description|
      @settings.description = description
    end # --description

    opts.on("--url URL",
            "Add a url for this package.") do |url|
      @settings.url = url
    end # --url

  end # def default_options
end # class FPM::Program
