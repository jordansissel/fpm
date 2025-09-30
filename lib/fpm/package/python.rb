require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

# Support for python packages.
#
# This supports input, but not output.
#
# Example:
#
#     # Download the django python package:
#     pkg = FPM::Package::Python.new
#     pkg.input("Django")
#
class FPM::Package::Python < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:python_foo]
  option "--bin", "PYTHON_EXECUTABLE",
    "The path to the python executable you wish to run.", :default => "python"
  option "--easyinstall", "EASYINSTALL_EXECUTABLE",
    "The path to the easy_install executable tool", :default => "easy_install"
  option "--pip", "PIP_EXECUTABLE",
    "The path to the pip executable tool. If not specified, easy_install " \
    "is used instead", :default => nil
  option "--pypi", "PYPI_URL",
    "PyPi Server uri for retrieving packages.",
    :default => "https://pypi.python.org/simple"
  option "--trusted-host", "PYPI_TRUSTED",
    "Mark this host or host:port pair as trusted for pip",
    :default => nil
  option "--package-prefix", "NAMEPREFIX",
    "(DEPRECATED, use --package-name-prefix) Name to prefix the package " \
    "name with." do |value|
    logger.warn("Using deprecated flag: --package-prefix. Please use " \
                 "--package-name-prefix")
    value
  end
  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "python"
  option "--fix-name", :flag, "Should the target package name be prefixed?",
    :default => true
  option "--fix-dependencies", :flag, "Should the package dependencies be " \
    "prefixed?", :default => true

  option "--downcase-name", :flag, "Should the target package name be in " \
    "lowercase?", :default => true
  option "--downcase-dependencies", :flag, "Should the package dependencies " \
    "be in lowercase?", :default => true

  option "--install-bin", "BIN_PATH", "(DEPRECATED, does nothing) The path to where python scripts " \
    "should be installed to." do
    logger.warn("Using deprecated flag --install-bin")
  end
  option "--install-lib", "LIB_PATH", "(DEPRECATED, does nothing) The path to where python libs " \
    "should be installed to (default depends on your python installation). " \
    "Want to find out what your target platform is using? Run this: " \
    "python -c 'from distutils.sysconfig import get_python_lib; " \
    "print get_python_lib()'" do
    logger.warn("Using deprecated flag --install-bin")
  end

  option "--install-data", "DATA_PATH", "(DEPRECATED, does nothing) The path to where data should be " \
    "installed to. This is equivalent to 'python setup.py --install-data " \
    "DATA_PATH" do
    logger.warn("Using deprecated flag --install-bin")
  end

  option "--dependencies", :flag, "Include requirements defined by the python package" \
    " as dependencies.", :default => true
  option "--obey-requirements-txt", :flag, "Use a requirements.txt file " \
    "in the top-level directory of the python package for dependency " \
    "detection.", :default => false
  option "--scripts-executable", "PYTHON_EXECUTABLE", "(DEPRECATED) Set custom python " \
    "interpreter in installing scripts. By default distutils will replace " \
    "python interpreter in installing scripts (specified by shebang) with " \
    "current python interpreter (sys.executable). This option is equivalent " \
    "to appending 'build_scripts --executable PYTHON_EXECUTABLE' arguments " \
    "to 'setup.py install' command." do
    logger.warn("Using deprecated flag --install-bin")
  end

  option "--disable-dependency", "python_package_name",
    "The python package name to remove from dependency list",
    :multivalued => true, :attribute_name => :python_disable_dependency,
    :default => []
  option "--setup-py-arguments", "setup_py_argument",
    "(DEPRECATED) Arbitrary argument(s) to be passed to setup.py",
    :multivalued => true, :attribute_name => :python_setup_py_arguments,
    :default => [] do
    logger.warn("Using deprecated flag --install-bin")
  end
  option "--internal-pip", :flag,
    "Use the pip module within python to install modules - aka 'python -m pip'. This is the recommended usage since Python 3.4 (2014) instead of invoking the 'pip' script",
    :attribute_name => :python_internal_pip,
    :default => true
 
    # Environment markers which are known but not yet supported by fpm.
    # For some of these markers, it's not even clear if they are useful to fpm's packaging step.
    # https://packaging.python.org/en/latest/specifications/dependency-specifiers/#dependency-specifiers
    # 
    # XXX: python's setuptools.pkg_resources can help parse and evaluate such things, even if that library is deprecated:
    # >>> f = open("spec/fixtures/python/requirements.txt"); a = pkg_resources.parse_requirements(f.read()); f.close();
    # >>> [x for x in list(a) if x.marker is None or x.marker.evaluate()]
    # [Requirement.parse('rtxt-dep1>0.1'), Requirement.parse('rtxt-dep2==0.1'), Requirement.parse('rtxt-dep4; python_version > "2.0"')]
    # 
    # Another example, showing only requirements which have environment markers which evaluate to true (or have no markers)
    # python3 -c 'import pkg_resources; import json;import sys; r = pkg_resources.parse_requirements(sys.stdin); deps = [d for d in list(r) if d.marker is None or d.marker.evaluate()]; pr
    # ["rtxt-dep1>0.1", "rtxt-dep2==0.1", "rtxt-dep4; python_version > \"2.0\""]
    UNSUPPORTED_DEPENDENCY_MARKERS = %w(python_version python_full_version os_name platform_release platform_system platform_version
      platform_machine platform_python_implementation implementation_name implementation_version)


  class PythonMetadata
    require "strscan"

    class MissingField < StandardError; end
    class UnexpectedContent < StandardError; end

    # According to https://packaging.python.org/en/latest/specifications/core-metadata/
    # > Core Metadata v2.4 - August 2024
    MULTIPLE_USE =  %w(Dynamic Platform Supported-Platform License-File Classifier Requires-Dist Requires-External Project-URL Provides-Extra Provides-Dist Obsoletes-Dist)

    # METADATA files are described in Python Packaging "Core Metadata"[1] and appear to have roughly RFC822 syntax.
    # [1] https://packaging.python.org/en/latest/specifications/core-metadata/#core-metadata
    def self.parse(input)
      s = StringScanner.new(input)
      headers = {}

      # Default "Multiple use" fields to empty array instead of nil.
      MULTIPLE_USE.each do |field|
        headers[field] = []
      end

      while !s.eos? and !s.scan("\n") do 
        # Field is non-space up, but excluding the colon
        field = s.scan(/[^\s:]+/)

        # Skip colon and following whitespace
        s.scan(/:\s*/)

        # Value is text until newline, and any following lines if they have leading spaces.
        value = s.scan(/[^\n]+(?:\Z|\n(?:[ \t][^\n]+\n)*)/)
        if value.nil?
          raise "Failed parsing Python package metadata value at field #{field}, char offset #{s.pos}"
        end
        value = value.chomp

        if MULTIPLE_USE.include?(field)
          raise "Header field should be an array. This is a bug in fpm." if !headers[field].is_a?(Array)
          headers[field] << value
        else
          headers[field] = value
        end
      end # while reading headers

      # If there's more content beyond the last header, then it's a content body.
      # In Python Metadata >= 2.1, the descriptino can be written in the body.
      if !s.eos? 
        if headers["Metadata-Version"].to_f >= 2.1
          # Per Python core-metadata spec:
          # > Changed in version 2.1: This field may be specified in the message body instead.
          #return PythonMetadata.new(headers, s.string[s.pos ...])
          return headers, s.string[s.pos ... ]
        else
          raise "After reading METADATA headers, extra data is in the file but was not expected. This may be a bug in fpm."
        end
      end

      #return PythonMetadata.new(headers)
      return headers, nil # nil means no body in this metadata
    rescue => e
      puts "String scan failed: #{e}"
      puts "Position: #{s.pointer}"
      puts "---"
      puts input
      puts "==="
      puts input[s.pointer...]
      puts "---"
      raise e
    end # self.parse

    def self.from(input)
      return PythonMetadata.new(*parse(input))
    end

    # Only focusing on terms fpm may care about
    attr_reader :name, :version, :summary, :description, :keywords, :maintainer, :license, :requires, :homepage

    FIELD_MAP = {
      :@name => "Name",
      :@version => "Version",
      :@summary => "Summary",
      :@description => "Description",
      :@keywords => "Keywords",
      :@maintainer => "Author-email",

      # Note: License can also come from the deprecated "License" field
      # This is processed later in this method.
      :@license => "License-Expression",

      :@requires => "Requires-Dist",
    }
    
    REQUIRED_FIELDS = [ "Metadata-Version", "Name", "Version" ]

    # headers - a Hash containing field-value pairs from headers as read from a python METADATA file.
    # body - optional, a string containing the body text of a METADATA file
    def initialize(headers, body=nil)
      REQUIRED_FIELDS.each do |field|
        if !headers.include?(field)
          raise MissingField, "Missing required Python metadata field, '#{field}'. This might be a bug in the package or in fpm."
        end
      end

      FIELD_MAP.each do |attr, field|
        if headers.include?(field)
          instance_variable_set(attr, headers.fetch(field))
        end
      end

      # Do any extra processing on fields to turn them into their expected content.
      process_description(headers, body)
      process_license(headers)
      process_homepage(headers)
      process_maintainer(headers)
    end # def initialize

    private
    def process_description(headers, body)
      if @description
        # Per python core-metadata spec:
        # > To support empty lines and lines with indentation with respect to the
        # > RFC 822 format, any CRLF character has to be suffixed by 7 spaces
        # > followed by a pipe (“|”) char. As a result, the Description field is
        # > encoded into a folded field that can be interpreted by RFC822 parser [2].
        @description = @description.gsub!(/^       |/, "")
      end

      if !body.nil?
        if headers["Metadata-Version"].to_f >= 2.1
          # Per Python core-metadata spec:
          # > Changed in version 2.1: [Description] field may be specified in the message body instead.
          # 
          # The description is simply the rest of the METADATA file after the headers.
          @description = body
        else
          raise UnexpectedContent, "Found a content body in METADATA file, but Metadata-Version(#{headers["Metadata-Version"]}) is below 2.1 and doesn't support this. This may be a bug in fpm or a malformed python package."
        end

        # What to do if we find a description body but already have a Description field set in the headers?
        if headers.include?("Description")
          raise "Found a description in the body of the python package metadata, but the package already set the Description field. I don't know what to do. This is probably a bug in fpm."
        end
      end

      # XXX: The description field can be markdown, plain text, or reST. 
      # Content type is noted in the "Description-Content-Type" field
      # Should we transform this to plain text?
    end # process_description

    def process_license(headers)
      # Ignore the "License" field if License-Expression is also present.
      return if headers["Metadata-Version"].to_f >= 2.4 && headers.include?("License-Expression")

      # Deprecated field, License,  as described in python core-metadata:
      # > As of Metadata 2.4, License and License-Expression are mutually exclusive. 
      # > If both are specified, tools which parse metadata will disregard License
      # > and PyPI will reject uploads. See PEP 639.
      if headers["License"]
        # Note: This license can be free form text, so it's unclear if it's a great choice.
        #       however, the original python metadata License field is quite old/deprecated
        #       so maybe nobody uses it anymore?
        @license = headers["License"]
      elsif license_classifier = headers["Classifier"].find { |value| value =~ /^License ::/ }
        # The license could also show up in the "Classifier" header with "License ::" as a prefix.
          @license = license_classifier.sub(/^License ::/, "")
      end # check for deprecated License field
    end # process_license

    def process_homepage(headers)
      return if headers["Project-URL"].empty?

      # Create a hash of Project-URL where the label is the key, url the value.
      urls = Hash[*headers["Project-URL"].map do |text|
        label, url = text.split(/, */, 2)
        # Normalize the label by removing punctuation and spaces
        # Reference: https://packaging.python.org/en/latest/specifications/well-known-project-urls/#label-normalization
        # > In plain language: a label is normalized by deleting all ASCII punctuation and whitespace, and then converting the result to lowercase.
        label = label.gsub(/[[:punct:][:space:]]/, "").downcase
        [label, url]
      end.flatten(1)]

      # Prioritize certain URL labels when choosing the homepage url.
      [ "homepage", "source", "documentation", "releasenotes" ].each do |label|
        if urls.include?(label)
          @homepage = urls[label]
        end
      end

      # Otherwise, default to the first URL
      @homepage = urls.values.first
    end

    def process_maintainer(headers)
      # Python metadata supports both "Author-email" and "Maintainer-email"
      # Of the "Maintainer" fields, python core-metadata says:
      # > Note that this field is intended for use when a project is being maintained by someone other than the original author
      #
      # So we should prefer Maintainer-email if it exists, but fall back to Author-email otherwise.
      @maintainer = headers["Maintainer-email"] unless headers["Maintainer-email"].nil?
    end
  end # class PythonMetadata

  # Input a package.
  #
  # The 'package' can be any of:
  #
  # * A name of a package on pypi (ie; easy_install some-package)
  # * The path to a directory containing setup.py or pypackage.toml
  # * The path to a setup.py or pypackage.toml
  # * The path to a python sdist file ending in .tar.gz
  # * The path to a python wheel file ending in .whl
  def input(package)
    #if attributes[:python_obey_requirements_txt?]
      #raise "--python-obey-requirements-txt is temporarily unsupported at this time."
    #end
    explore_environment

    path_to_package = download_if_necessary(package, version)

    # Expect a setup.py or pypackage.toml if it's a directory.
    if File.directory?(path_to_package)
      if !(File.exist?(File.join(path_to_package, "setup.py")) or File.exist?(File.join(path_to_package, "pypackage.toml")))
        logger.error("The path doesn't appear to be a python package directory. I expected either a pypackage.toml or setup.py but found neither.", :package => package)
        raise "Unable to find python package; tried #{setup_py}"
      end

      if attributes[:python_obey_requirements_txt?] && File.exist?(File.join(path_to_package, "requirements.txt"))
        @requirements_txt = File.read(File.join(path_to_package, "requirements.txt"))
      end
    end

    if File.file?(path_to_package)
      if ["setup.py", "pypackage.toml"].include?(File.basename(path_to_package))
        path_to_package = File.dirname(path_to_package)
      end
    end

    if path_to_package.end_with?(".tar.gz")
      # Have pip convert the .tar.gz (source dist?) into a wheel
      logger.debug("Found tarball and assuming it's a python source package.")
      safesystem(*attributes[:python_pip], "wheel", "--no-deps", "-w", build_path, path_to_package)

      path_to_package = ::Dir.glob(build_path("*.whl")).first
      if path_to_package.nil?
        log.error("Failed building python package wheel format. This might be a bug in fpm.")
        raise "Failed building python package format."
      end
    elsif File.directory?(path_to_package)
      logger.debug("Found directory and assuming it's a python source package.")
      safesystem(*attributes[:python_pip], "wheel", "--no-deps", "-w", build_path, path_to_package)

      path_to_package = ::Dir.glob(build_path("*.whl")).first
      if path_to_package.nil?
        log.error("Failed building python package wheel format. This might be a bug in fpm.")
        raise "Failed building python package format."
      end
    end

    load_package_info(path_to_package)
    install_to_staging(path_to_package)
  end # def input

  def explore_environment
    if !attributes[:python_bin_given?]
      # If --python-bin isn't set, try to find a good default python executable path, because it might not be "python"
      pythons = [ "python", "python3", "python2" ]
      default_python = pythons.find { |py| program_exists?(py) }

      if default_python.nil?
        raise FPM::Util::ExecutableNotFound, "Could not find any python interpreter. Tried the following: #{pythons.join(", ")}"
      end

      logger.info("Setting default python executable", :name => default_python)
      attributes[:python_bin] = default_python

      if !attributes[:python_package_name_prefix_given?]
        attributes[:python_package_name_prefix] = default_python
        logger.info("Setting package name prefix", :name => default_python)
      end
    end

    if attributes[:python_internal_pip?]
      # XXX: Should we detect if internal pip is available?
      attributes[:python_pip] = [ attributes[:python_bin], "-m", "pip"]
    end
  end # explore_environment



  # Download the given package if necessary. If version is given, that version
  # will be downloaded, otherwise the latest is fetched.
  def download_if_necessary(package, version=nil)
    path = package

    # If it's a path, assume local build.
    if File.exist?(path)
      return path if File.directory?(path)
      return path if path.end_with?(".tar.gz")
      return path if path.end_with?(".whl")
      return path if path.end_with?(".zip")
      return path if File.exist?(File.join(path, "setup.py"))
      return path if File.exist?(File.join(path, "pyproject.toml"))

      raise [
        "Local file doesn't appear to be a supported type for a python package. Expected one of:",
        "  - A directory containing setup.py or pyproject.toml",
        "  - A file ending in .tar.gz (a python source dist)",
        "  - A file ending in .whl (a python wheel)",
      ].join("\n")
    end

    logger.info("Trying to download", :package => package)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end

    target = build_path(package)
    FileUtils.mkdir(target) unless File.directory?(target)

    # attributes[:python_pip] -- expected to be a path
    if attributes[:python_pip]
      logger.debug("using pip", :pip => attributes[:python_pip])
      pip = [attributes[:python_pip]] if pip.is_a?(String)
      setup_cmd = [
        *attributes[:python_pip],
        "download",
        "--no-clean",
        "--no-deps",
        "-d", target,
        "-i", attributes[:python_pypi],
      ]

      if attributes[:python_trusted_host]
        setup_cmd += [
          "--trusted-host",
          attributes[:python_trusted_host],
        ]
      end

      setup_cmd << want_pkg

      safesystem(*setup_cmd)

      #files = ::Dir.glob(File.join(target, "*.{whl,tar.gz,zip}"))
      files = ::Dir.entries(target).filter { |entry| entry =~ /\.(whl|tar\.gz|zip)$/ }
      if files.length != 1
        raise "Unexpected directory layout after `pip download ...`. This might be an fpm bug? The directory contains these files: #{files.inspect}"
      end
      return File.join(target, files.first)
    else
      # no pip, use easy_install
      logger.debug("no pip, defaulting to easy_install", :easy_install => attributes[:python_easyinstall])
      safesystem(attributes[:python_easyinstall], "-i",
                 attributes[:python_pypi], "--editable", "-U",
                 "--build-directory", target, want_pkg)
      # easy_install will put stuff in @tmpdir/packagename/, so find that:
      #  @tmpdir/somepackage/setup.py
      #dirs = ::Dir.glob(File.join(target, "*"))
      files = ::Dir.entries(target).filter { |entry| entry != "." && entry != ".." }
      if dirs.length != 1
        raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{build_path}"
      end
      return dirs.first
    end
  end # def download

  # Load the package information like name, version, dependencies.
  def load_package_info(path)
    if path.end_with?(".whl")
      # XXX: Maybe use rubyzip to parse the .whl (zip) file instead?
      metadata = nil
      execmd(["unzip", "-p", path, "*.dist-info/METADATA"], :stdin => false, :stderr => false) do |stdout|
        metadata = PythonMetadata.from(stdout.read(64<<10))
      end

      wheeldata = nil
      execmd(["unzip", "-p", path, "*.dist-info/WHEEL"], :stdin => false, :stderr => false) do |stdout|
        wheeldata, _ = PythonMetadata.parse(stdout.read(64<<10))
      end
    else
      raise "Unexpected python package path. This might be an fpm bug? The path is #{path}"
    end

    self.architecture = wheeldata["Root-Is-Purelib"] == "true" ? "all" : "native"

    self.description = metadata.description unless metadata.description.nil?
    self.license = metadata.license unless metadata.license.nil?
    self.version = metadata.version
    self.url = metadata.homepage unless metadata.homepage.nil?

    self.name = metadata.name

    # name prefixing is optional, if enabled, a name 'foo' will become
    # 'python-foo' (depending on what the python_package_name_prefix is)
    self.name = fix_name(self.name) if attributes[:python_fix_name?] 

    # convert python-Foo to python-foo if flag is set
    self.name = self.name.downcase if attributes[:python_downcase_name?]

    self.maintainer = metadata.maintainer 

    if !attributes[:no_auto_depends?] and attributes[:python_dependencies?]
      # Python Dependency specifiers are a somewhat complex format described here:
      # https://packaging.python.org/en/latest/specifications/dependency-specifiers/#environment-markers
      #
      # We can ask python's packaging module to parse and evaluate these.
      # XXX: Allow users to override environnment values.
      #
      # Example:
      # Requires-Dist: tzdata; sys_platform = win32
      # Requires-Dist: asgiref>=3.8.1

      dep_re = /^([^<>!= ]+)\s*(?:([~<>!=]{1,2})\s*(.*))?$/

      reqs = []

      # --python-obey-requirements-txt should replace the requirments listed from the metadata
      if attributes[:python_obey_requirements_txt?] && !@requirements_txt.nil?
        requires = @requirements_txt.split("\n")
      else
        requires = metadata.requires
      end

      # Evaluate python package requirements and only show ones matching the current environment
      # (Environment markers, etc)
      # Additionally, 'extra' features such as a requirement named `django[bcrypt]` isn't quite supported yet,
      # since the marker.evaluate() needs to be passed some environment like { "extra": "bcrypt" }
      execmd([attributes[:python_bin], File.expand_path(File.join("pyfpm", "parse_requires.py"), File.dirname(__FILE__))]) do |stdin, stdout, stderr|
        requires.each { |r| stdin.puts(r) }
        stdin.close
        data = stdout.read
        logger.pipe(stderr => :warn)
        reqs += JSON.parse(data)
      end

      reqs.each do |dep|
        match = dep_re.match(dep)
        if match.nil?
          logger.error("Unable to parse dependency", :dependency => dep)
          raise FPM::InvalidPackageConfiguration, "Invalid dependency '#{dep}'"
        end

        name, cmp, version = match.captures

        next if attributes[:python_disable_dependency].include?(name)

        # convert == to =
        if cmp == "==" or cmp == "~="
          logger.info("Converting == dependency requirement to =", :dependency => dep )
          cmp = "="
        end

        # dependency name prefixing is optional, if enabled, a name 'foo' will
        # become 'python-foo' (depending on what the python_package_name_prefix
        # is)
        name = fix_name(name) if attributes[:python_fix_dependencies?]

        # convert dependencies from python-Foo to python-foo
        name = name.downcase if attributes[:python_downcase_dependencies?]

        if cmp.nil? && version.nil?
          self.dependencies << "#{name}"
        else
          self.dependencies << "#{name} #{cmp} #{version}"
        end
      end # parse Requires-Dist dependencies
    end # if attributes[:python_dependencies?]
  end # def load_package_info

  # Sanitize package name.
  # Some PyPI packages can be named 'python-foo', so we don't want to end up
  # with a package named 'python-python-foo'.
  # But we want packages named like 'pythonweb' to be suffixed
  # 'python-pythonweb'.
  def fix_name(name)
    if name.start_with?("python")
      # If the python package is called "python-foo" strip the "python-" part while
      # prepending the package name prefix.
      return [attributes[:python_package_name_prefix], name.gsub(/^python-/, "")].join("-")
    else
      return [attributes[:python_package_name_prefix], name].join("-")
    end
  end # def fix_name

  # Install this package to the staging directory
  def install_to_staging(path)
    prefix = "/"
    prefix = attributes[:prefix] unless attributes[:prefix].nil?

    # XXX: Note: pip doesn't seem to have any equivalent to `--install-lib` or similar flags.
    # XXX: Deprecate :python_install_data, :python_install_lib, :python_install_bin
    # XXX: Deprecate: :python_setup_py_arguments
    flags = [ "--root", staging_path ]
    flags += [ "--prefix", prefix ] if !attributes[:prefix].nil?

    safesystem(*attributes[:python_pip], "install", "--no-deps", *flags, path)
  end # def install_to_staging

  public(:input)
end # class FPM::Package::Python
