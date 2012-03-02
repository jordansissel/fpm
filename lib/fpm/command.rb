require "rubygems"
require "fpm/namespace"
require "clamp"
require "ostruct"
require "fpm"

# The main fpm command entry point.
class FPM::Command < Clamp::Command
  option "-t", "OUTPUT_TYPE",
    "the type of package you want to create (deb, rpm, solaris, etc)",
    :attribute_name => :output_type
  option "-s", "INPUT_TYPE",
    "the package type to use as input (gem, rpm, python, etc)",
    :attribute_name => :input_type
  option "-C", "CHDIR",
    "Change directory to here before searching for files", :attribute_name => :chdir
  option "--prefix", "PREFIX",
    "A path to prefix files with when building the target package. This may " \
    "be necessary for all input packages. For example, the 'gem' type will" \
    "prefix with your gem directory automatically."
  option ["-p", "--package"], "OUTPUT",
    "The package file path to output.", :default => "NAME-FULLVERSION.ARCH.TYPE"
  option ["-n", "--name"], "NAME", "The name to give to the package"
  option "--verbose", :flag, "Enable verbose output"
  option "--debug", :flag, "Enable debug output"
  option ["-v", "--version"], "VERSION",
    "The version to give to the package", :default => "1.0"
  option "--iteration", "ITERATION",
    "The iteration to give to the package. RPM calls this the 'release'. " \
    "FreeBSD calls it 'PORTREVISION'. Debian calls this 'debian_revision'",
    :default => "1"
  option "--epoch", "EPOCH",
    "The epoch value for this package. RPM and Debian calls this 'epoch'. " \
    "FreeBSD calls this 'PORTEPOCH'", :default => "1"
  option "--license", "LICENSE",
    "(optional) license name for this package", :default => "not given"
  option "--vendor", "VENDOR",
    "(optional) vendor name for this package", :default => "not given"
  option "--category", "CATEGORY",
    "(optional) category this package belongs to", :default => "none"
  option ["-d", "--depends"], "DEPENDENCY",
    "A dependency. This flag can be specified multiple times. Value is " \
    "usually in the form of: -d 'name' or -d 'name > version'",
    :default => [], :attribute_name => :dependencies do |val|
    # Clamp doesn't support multivalue flags (ie; specifying -d multiple times)
    # so we can hack around it with this trickery.
    @dependencies ||= []
    @dependencies << val
  end # -d / --depends
  option "--provides", "PROVIDES",
    "What this package provides (usually a name)" do |val|
    @provides ||= []
    @provides << val
  end # --provides
  option "--conflicts", "CONFLICTS",
    "Other packages/versions this package conflicts with" do |val|
    @conflicts ||= []
    @conflicts << val
  end # --conflicts
  option "--replaces", "REPLACES",
    "Other packages/versions this package replaces" do |val|
    @replaces ||= []
    @replaces << val
  end # --replaces
  option "--config-files", "CONFIG_FILES",
    "Mark a file in the package as being a config file. This uses 'conffiles'" \
    " in debs and %config in rpm." do |val|
    @config_files ||= []
    @config_files << val
  end # --config-files
  option ["-a", "--architecture"], "ARCHITECTURE",
    "The architecture name. Usually matches 'uname -m'. For automatic values," \
    " you can use '-a all' or '-a native'. These two strings will be " \
    "translated into the correct value for your platform and target package type."
  option ["-m", "--maintainer"], "MAINTAINER",
    "The maintainer of this package.",
    :default => "<#{ENV["USER"]}@#{Socket.gethostname}>"
  option ["-S", "--package-name-suffix"], "PACKAGE_NAME_SUFFIX",
    "a name suffix to append to package and dependencies."
  option ["-e", "--edit"], :flag,
    "Edit the package spec before building."
  option ["-x", "--exclude"], "EXCLUDE_PATTERN",
    "Exclude paths matching pattern (shell wildcard globs valid here)" do |val|
    @exclude_pattern ||= []
    @exclude_pattern << val
  end # -x / --exclude
  option "--post-install", "FILE",
    "a script to be run after package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --post-install
  option "--pre-install", "FILE",
    "a script to be run before package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --pre-install
  # TODO(sissel): Name the flag --post-remove for clarity
  option "--post-uninstall", "FILE",
    "a script to be run after package removal",
    :attribute_name => :post_remove do |val|
    File.expand_path(val) # Get the full path to the script
  end # --post-uninstall
  # TODO(sissel): Name the flag --pre-remove for clarity
  option "--pre-uninstall", "FILE",
    "a script to be run before package removal",
    :attribute_name => :pre_remove do |val|
    File.expand_path(val) # Get the full path to the script
  end # --pre-uninstall
  option "--description", "DESCRIPTION", "Add a description for this package.",
    :default => "no description"
  option "--url", "URI", "Add a url for this package.",
    :default => "http://example.com/no-uri-given"
  option "--inputs", "INPUTS_PATH",
    "The path to a file containing a newline-separated list of " \
    "files and dirs to use as input."
  parameter "[ARGS] ...",
    "Inputs to the source package type. For the 'dir' type, this is the files" \
    " and directories you want to include in the package. For others, like " \
    "'gem', it specifies the packages to download and use as the gem input",
    :attribute_name => :args

  # TODO(sissel): expose 'option' and 'parameter' junk to FPM::Package and subclasses.
  # Apply those things to this command.
  #
  # Add extra flags from plugins
  #FPM::Package::Gem.flags(FPM::Flags.new(opts, "gem", "gem only"), @settings)
  #FPM::Package::Python.flags(FPM::Flags.new(opts, "python", "python only"),
                            #@settings)
  #FPM::Package::Deb.flags(FPM::Flags.new(opts, "deb", "deb only"), @settings)
  #FPM::Package::Rpm.flags(FPM::Flags.new(opts, "rpm", "rpm only"), @settings)
  
  # A new FPM::Command
  def initialize(*args)
    super(*args)
    @conflicts = []
    @replaces = []
    @provides = []
    @dependencies = []
    @config_files = []
  end # def initialize

  # Execute this command. See Clamp::Command#execute and Clamp's documentation
  def execute
    @logger = Cabin::Channel.get
    @logger.subscribe(STDOUT)
    @logger.level = :warn
    validator = Validator.new(self)
    if !validator.ok?
      validator.messages.each do |message|
        @logger.error(message)
      end
      return 1
    end

    input_class = FPM::Package.types[input_type]
    output_class = FPM::Package.types[output_type]

    if input_class.nil?
      @logger.error("Unknown input package type '#{input_type}'", :choices => FPM::Package.types.keys)
      return 1
    end

    if output_class.nil?
      @logger.error("Unknown output package type '#{output_type}'", :choices => FPM::Package.types.keys)
      return 1
    end

    @logger.level = :info if verbose? # --verbose
    @logger.level = :debug if debug? # --debug

    input = input_class.new
    args.each { |arg| input.input(arg) }

    input.architecture = architecture
    #input.attributes = {}
    input.category = category
    input.config_files = config_files
    input.description = description
    input.epoch = epoch
    input.iteration = iteration
    input.license = license
    input.maintainer = maintainer
    input.name = name
    input.scripts[:post_install] = 
    input.url = url
    input.vendor = vendor
    input.version = version

    input.conflicts += conflicts
    input.dependencies += dependencies
    input.provides += provides
    input.replaces += replaces

    output = input.convert(output_class)
    output.output(output.to_s(package))
    return 0
  ensure
    input.cleanup
    output.cleanup unless output.nil?
  end # def execute

  # A simple flag validator
  #
  # The goal of this class is to ensure the flags and arguments given
  # are a valid configuration.
  class Validator
    private

    def initialize(command)
      @command = command
      @valid = true
      @messages = []

      validate
    end # def initialize

    def ok?
      return @valid
    end # def ok?

    def validate
      mandatory(@command.input_type, "No input package type (-s flag) specified.")
      mandatory(@command.output_type, "No output package type (-t flag) specified.")
    end # def validate

    def mandatory(value, message)
      if value.nil?
        @messages << message
        @valid = false
      end
    end # def mandatory

    def messages
      return @messages
    end # def messages

    public(:initialize, :ok?, :messages)
  end # class Validator
end # class FPM::Program
