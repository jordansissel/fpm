require "rubygems"
require "fpm/namespace"
require "fpm/util"
require "clamp"
require "ostruct"
require "fpm"
require "tmpdir" # for Dir.tmpdir

if $DEBUG
  Cabin::Channel.get(Kernel).subscribe($stdout)
  Cabin::Channel.get(Kernel).level = :debug
end

Dir[File.join(File.dirname(__FILE__), "package", "*.rb")].each do |plugin|
  Cabin::Channel.get(Kernel).info("Loading plugin", :path => plugin)
  require plugin
end


# The main fpm command entry point.
class FPM::Command < Clamp::Command
  include FPM::Util

  option "-t", "OUTPUT_TYPE",
    "the type of package you want to create (deb, rpm, solaris, etc)",
    :attribute_name => :output_type
  option "-s", "INPUT_TYPE",
    "the package type to use as input (gem, rpm, python, etc)",
    :attribute_name => :input_type
  option "-C", "CHDIR",
    "Change directory to here before searching for files",
    :attribute_name => :chdir
  option "--prefix", "PREFIX",
    "A path to prefix files with when building the target package. This may " \
    "be necessary for all input packages. For example, the 'gem' type will" \
    "prefix with your gem directory automatically."
  option ["-p", "--package"], "OUTPUT", "The package file path to output."
  option ["-n", "--name"], "NAME", "The name to give to the package"
  option "--verbose", :flag, "Enable verbose output"
  option "--debug", :flag, "Enable debug output"
  option ["-v", "--version"], "VERSION", "The version to give to the package",
    :default => 1.0
  option "--iteration", "ITERATION",
    "The iteration to give to the package. RPM calls this the 'release'. " \
    "FreeBSD calls it 'PORTREVISION'. Debian calls this 'debian_revision'"
  option "--epoch", "EPOCH",
    "The epoch value for this package. RPM and Debian calls this 'epoch'. " \
    "FreeBSD calls this 'PORTEPOCH'"
  option "--license", "LICENSE",
    "(optional) license name for this package"
  option "--vendor", "VENDOR",
    "(optional) vendor name for this package"
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
    "What this package provides (usually a name). This flag can be "\
    "specified multiple times." do |val|
    @provides ||= []
    @provides << val
  end # --provides
  option "--conflicts", "CONFLICTS",
    "Other packages/versions this package conflicts with. This flag can " \
    "specified multiple times." do |val|
    @conflicts ||= []
    @conflicts << val
  end # --conflicts
  option "--replaces", "REPLACES",
    "Other packages/versions this package replaces. This flag can be "\
    "specified multiple times." do |val|
    @replaces ||= []
    @replaces << val
  end # --replaces
  option "--config-files", "CONFIG_FILES",
    "Mark a file in the package as being a config file. This uses 'conffiles'" \
    " in debs and %config in rpm. If you have multiple files to mark as " \
    "configuration files, specify this flag multiple times." do |val|
    #You can specify a directory to have it scanned marking all files found as
    #config files. If you have multiple "
    @config_files ||= []
    @config_files << val
  end # --config-files
  option "--directories", "DIRECTORIES",
    "Mark a directory as being owned by the package" \
    do |val|
    @directories ||= []
    @directories << val
  end # directories
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
    "Edit the package spec before building.", :default => false
  option ["-x", "--exclude"], "EXCLUDE_PATTERN",
    "Exclude paths matching pattern (shell wildcard globs valid here). " \
    "If you have multiple file patterns to exclude, specify this flag " \
    "multiple times.", :attribute_name => :excludes do |val|
    @excludes ||= []
    @excludes << val
  end # -x / --exclude
  option "--description", "DESCRIPTION", "Add a description for this package." \
    " You can include '\n' sequences to indicate newline breaks.",
    :default => "no description" do |val|
    # Replace literal "\n" sequences with a newline character.
    val.gsub("\\n", "\n")
  end
  option "--url", "URI", "Add a url for this package.",
    :default => "http://example.com/no-uri-given"
  option "--inputs", "INPUTS_PATH",
    "The path to a file containing a newline-separated list of " \
    "files and dirs to use as input."

  option "--post-install", "FILE",
    "(DEPRECATED, use --after-install) a script to be run after " \
    "package installation" do |val|
    @after_install = File.expand_path(val) # Get the full path to the script
  end # --post-install (DEPRECATED)
  option "--pre-install", "FILE",
    "(DEPRECATED, use --before-install) a script to be run before " \
    "package installation" do |val|
    @before_install = File.expand_path(val) # Get the full path to the script
  end # --pre-install (DEPRECATED)
  option "--post-uninstall", "FILE",
      "(DEPRECATED, use --after-remove) a script to be run after " \
      "package removal" do |val|
    @after_remove = File.expand_path(val) # Get the full path to the script
  end # --post-uninstall (DEPRECATED)
  option "--pre-uninstall", "FILE",
    "(DEPRECATED, use --before-remove) a script to be run before " \
    "package removal"  do |val|
    @before_remove = File.expand_path(val) # Get the full path to the script
  end # --pre-uninstall (DEPRECATED)

  option "--after-install", "FILE",
    "a script to be run after package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-install
  option "--before-install", "FILE",
    "a script to be run before package installation" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --pre-install
  option "--after-remove", "FILE",
    "a script to be run after package removal" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --after-remove
  option "--before-remove", "FILE",
    "a script to be run before package removal" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --before-remove
  option "--template-scripts", :flag,
    "Allow scripts to be templated. This lets you use ERB to template your " \
    "packaging scripts (for --after-install, etc). For example, you can do " \
    "things like <%= name %> to get the package name. For more information, " \
    "see the fpm wiki: " \
    "https://github.com/jordansissel/fpm/wiki/Script-Templates"

  option "--template-value", "KEY=VALUE",
    "Make 'key' available in script templates, so <%= key %> given will be " \
    "the provided value. Implies --template-scripts" do |kv|
    @template_scripts = true
    @template_values ||= []
    @template_values << kv.split("=", 2)
  end

  option "--workdir", "WORKDIR",
    "The directory you want fpm to do its work in, where 'work' is any file" \
    "copying, downloading, etc. Roughly any scratch space fpm needs to build" \
    "your package.", :default => Dir.tmpdir

  parameter "[ARGS] ...",
    "Inputs to the source package type. For the 'dir' type, this is the files" \
    " and directories you want to include in the package. For others, like " \
    "'gem', it specifies the packages to download and use as the gem input",
    :attribute_name => :args

  FPM::Package.types.each do |name, klass|
    klass.apply_options(self)
  end

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
    @directories = []
    @excludes = []
  end # def initialize

  # Execute this command. See Clamp::Command#execute and Clamp's documentation
  def execute
    @logger = Cabin::Channel.get
    @logger.subscribe(STDOUT)
    @logger.level = :warn

    if (stray_flags = args.grep(/^-/); stray_flags.any?)
      @logger.warn("All flags should be before the first argument " \
                   "(stray flags found: #{stray_flags}")
    end

    # Some older behavior, if you specify:
    #   'fpm -s dir -t ... -C somepath'
    # fpm would assume you meant to add '.' to the end of the commandline.
    # Let's hack that. https://github.com/jordansissel/fpm/issues/187
    if input_type == "dir" and args.empty? and !chdir.nil?
      @logger.info("No args, but -s dir and -C are given, assuming '.' as input") 
      args << "."
    end

    @logger.info("Setting workdir", :workdir => workdir)
    ENV["TMP"] = workdir

    validator = Validator.new(self)
    if !validator.ok?
      validator.messages.each do |message|
        @logger.warn(message)
      end

      @logger.fatal("Fix the above problems, and you'll be rolling packages in no time!")
      return 1
    end
    input_class = FPM::Package.types[input_type]
    output_class = FPM::Package.types[output_type]

    @logger.level = :info if verbose? # --verbose
    @logger.level = :debug if debug? # --debug

    input = input_class.new

    # Merge in package settings. 
    # The 'settings' stuff comes in from #apply_options, which goes through
    # all the options defined in known packages and puts them into our command.
    # Flags in packages defined as "--foo-bar" become named "--<packagetype>-foo-bar"
    # They are stored in 'settings' as :gem_foo_bar.
    input.attributes ||= {}

    # Iterate over all the options and set their values in the package's
    # attribute hash.
    #
    # Things like '--foo-bar' will be available as pkg.attributes[:foo_bar]
    self.class.declared_options.each do |option|
      with(option.attribute_name) do |attr|
        next if attr == "help"
        # clamp makes option attributes available as accessor methods
        # --foo-bar is available as 'foo_bar'. Put these in the package
        # attributes hash. (See FPM::Package#attributes)
        # 
        # In the case of 'flag' options, the accessor is actually 'foo_bar?'
        # instead of just 'foo_bar'
       
        # If the instance variable @{attr} is defined, then
        # it means the flag was given on the command line.
        flag_given = instance_variable_defined?("@#{attr}")
        input.attributes["#{attr}_given?".to_sym] = flag_given
        attr = "#{attr}?" if !respond_to?(attr) # handle boolean :flag cases
        input.attributes[attr.to_sym] = send(attr) if respond_to?(attr)
        @logger.debug("Setting attribute", attr.to_sym => send(attr))
      end
    end

    # Each remaining command line parameter is used as an 'input' argument.
    # For directories, this means paths. For things like gem and python, this
    # means package name or paths to the packages (rails, foo-1.0.gem, django,
    # bar/setup.py, etc)
    args.each do |arg| 
      input.input(arg) 
    end

    # If --inputs was specified, read it as a file.
    if !inputs.nil?
      if !File.exists?(inputs)
        @logger.fatal("File given for --inputs does not exist (#{inputs})")
        return 1
      end

      # Read each line as a path
      File.new(inputs, "r").each_line do |line| 
        # Handle each line as if it were an argument
        input.input(line)
      end
    end

    # Override package settings if they are not the default flag values
    # the below proc essentially does:
    #
    # if someflag != default_someflag
    #   input.someflag = someflag
    # end
    set = proc do |object, attribute|
      # if the package's attribute is currently nil *or* the flag setting for this
      # attribute is non-default, use the value.
      if object.send(attribute).nil? || send(attribute) != send("default_#{attribute}")
        @logger.info("Setting from flags: #{attribute}=#{send(attribute)}")
        object.send("#{attribute}=", send(attribute))
      end
    end
    set.call(input, :architecture)
    set.call(input, :category)
    set.call(input, :description)
    set.call(input, :epoch)
    set.call(input, :iteration)
    set.call(input, :license)
    set.call(input, :maintainer)
    set.call(input, :name)
    set.call(input, :url)
    set.call(input, :vendor)
    set.call(input, :version)
    set.call(input, :architecture)

    input.conflicts += conflicts
    input.dependencies += dependencies
    input.provides += provides
    input.replaces += replaces
    input.config_files += config_files
    input.directories += directories
    
    setscript = proc do |scriptname|
      # 'self.send(scriptname) == self.before_install == --before-install
      # Gets the path to the script
      path = self.send(scriptname)
      # Skip scripts not set
      next if path.nil?

      if !File.exists?(path)
        @logger.error("No such file (for #{scriptname.to_s}): #{path.inspect}")
        return 1
      end

      # Load the script into memory.
      input.scripts[scriptname] = File.read(path)
    end

    setscript.call(:before_install)
    setscript.call(:after_install)
    setscript.call(:before_remove)
    setscript.call(:after_remove)

    # Validate the package
    if input.name.nil? or input.name.empty?
      @logger.fatal("No name given for this package (set name with, " \
                    "for example, '-n packagename')")
      return 1
    end

    # Convert to the output type
    output = input.convert(output_class)

    # Provide any template values as methods on the package.
    if !@template_values.nil?
      @template_values.each do |key, value|
        (class << output; self; end).send(:define_method, key) { value }
      end
    end

    # Write the output somewhere, package can be nil if no --package is specified, 
    # and that's OK.
    begin
      output.output(output.to_s(package))
    rescue FPM::Package::FileAlreadyExists => e
      @logger.fatal(e.message)
      return 1
    rescue FPM::Package::ParentDirectoryMissing => e
      @logger.fatal(e.message)
      return 1
    end

    return 0
  rescue FPM::Util::ExecutableNotFound => e
    @logger.error("Need executable '#{e}' to convert #{input_type} to #{output_type}")
    return 1
  rescue FPM::InvalidPackageConfiguration => e
    @logger.error("Invalid package configuration: #{e}")
    return 1
  ensure
    input.cleanup unless input.nil?
    output.cleanup unless output.nil?
  end # def execute

  # A simple flag validator
  #
  # The goal of this class is to ensure the flags and arguments given
  # are a valid configuration.
  class Validator
    include FPM::Util
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
      # Make sure the user has passed '-s' and '-t' flags
      mandatory(@command.input_type,
                "Missing required -s flag. What package source did you want?")
      mandatory(@command.output_type,
                "Missing required -t flag. What package output did you want?")

      # Verify the types requested are valid
      types = FPM::Package.types.keys.sort
      with(@command.input_type) do |val|
        next if val.nil?
        mandatory(FPM::Package.types.include?(val),
                  "Invalid input package -s flag) type #{val.inspect}. " \
                  "Expected one of: #{types.join(", ")}")
      end

      with(@command.output_type) do |val|
        next if val.nil?
        mandatory(FPM::Package.types.include?(val),
                  "Invalid output package (-t flag) type #{val.inspect}. " \
                  "Expected one of: #{types.join(", ")}")
      end

      with (@command.dependencies) do |dependencies|
        # Verify dependencies don't include commas (#257)
        dependencies.each do |dep|
          next unless dep.include?(",")
          splitdeps = dep.split(/\s*,\s*/)
          @messages << "Dependencies should not " \
            "include commas. If you want to specify multiple dependencies, use " \
            "the '-d' flag multiple times. Example: " + \
            splitdeps.map { |d| "-d '#{d}'" }.join(" ")
        end
      end

      mandatory(@command.args.any?,
                "No parameters given. You need to pass additional command " \
                "arguments so that I know what you want to build packages " \
                "from. For example, for '-s dir' you would pass a list of " \
                "files and directories. For '-s gem' you would pass a one" \
                " or more gems to package from. As a full example, this " \
                "will make an rpm of the 'json' rubygem: " \
                "`fpm -s gem -t rpm json`")
    end # def validate

    def mandatory(value, message)
      if value.nil? or !value
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
