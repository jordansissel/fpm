require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"

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

  option "--install-bin", "BIN_PATH", "The path to where python scripts " \
    "should be installed to."
  option "--install-lib", "LIB_PATH", "The path to where python libs " \
    "should be installed to (default depends on your python installation). " \
    "Want to find out what your target platform is using? Run this: " \
    "python -c 'from distutils.sysconfig import get_python_lib; " \
    "print get_python_lib()'"
  option "--install-data", "DATA_PATH", "The path to where data should be " \
    "installed to. This is equivalent to 'python setup.py --install-data " \
    "DATA_PATH"
  option "--dependencies", :flag, "Include requirements defined in setup.py" \
    " as dependencies.", :default => true
  option "--obey-requirements-txt", :flag, "Use a requirements.txt file " \
    "in the top-level directory of the python package for dependency " \
    "detection.", :default => false
  option "--scripts-executable", "PYTHON_EXECUTABLE", "Set custom python " \
    "interpreter in installing scripts. By default distutils will replace " \
    "python interpreter in installing scripts (specified by shebang) with " \
    "current python interpreter (sys.executable). This option is equivalent " \
    "to appending 'build_scripts --executable PYTHON_EXECUTABLE' arguments " \
    "to 'setup.py install' command."
  option "--disable-dependency", "python_package_name",
    "The python package name to remove from dependency list",
    :multivalued => true, :attribute_name => :python_disable_dependency,
    :default => []
  option "--setup-py-arguments", "setup_py_argument",
    "Arbitrary argument(s) to be passed to setup.py",
    :multivalued => true, :attribute_name => :python_setup_py_arguments,
    :default => []
  option "--internal-pip", :flag,
    "Use the pip module within python to install modules - aka 'python -m pip'. This is the recommended usage since Python 3.4 (2014) instead of invoking the 'pip' script",
    :attribute_name => :python_internal_pip,
    :default => true

  module PythonMetadata
    require "strscan"

    # According to https://packaging.python.org/en/latest/specifications/core-metadata/
    # > Core Metadata v2.4 - August 2024
    MULTIPLE_USE =  %w(Dynamic Platform Supported-Platform License-File Classifier Requires-Dist Requires-External Project-URL Provides-Extra Provides-Dist Obsoletes-Dist)

    # METADATA files are described in Python Packaging "Core Metadata"[1] and appear to have roughly RFC822 syntax.
    # [1] https://packaging.python.org/en/latest/specifications/core-metadata/#core-metadata
    def from(input)
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
        #value = s.scan(/[^\n]+(?:$|\n(?:[ \t][^\n]+\n)*)/)
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
      end

      # Do any extra processing on fields to turn them into their expected content.
      #
      if headers["Description"]
        # Per python core-metadata spec:
        # > To support empty lines and lines with indentation with respect to the
        # > RFC 822 format, any CRLF character has to be suffixed by 7 spaces
        # > followed by a pipe (“|”) char. As a result, the Description field is
        # > encoded into a folded field that can be interpreted by RFC822 parser [2].
        headers["Description"].gsub!(/^       |/, "")
      end

      # If there's more content beyond the last header, then it's a content body.
      # In Python Metadata >= 2.1, the descriptino can be written in the body.
      if !s.eos? 
        if headers["Metadata-Version"].to_f >= 2.1
          # Per Python core-metadata spec:
          # > Changed in version 2.1: This field may be specified in the message body instead.

          if !headers["Description"].nil?
            # What to do if we find a description body but already have a Description field set in the headers?
            raise "Found a description in the body of the python package metadata, but the package already set the Description field. I don't know what to do. This is probably a bug in fpm."
          end

          # The description is simply the rest of the METADATA file after the headers.
          headers["Description"] = s.string[s.pos ...]

          # XXX: The description field can be markdown, plain text, or reST. 
          # Content type is noted in the "Description-Content-Type" field
          # Should we transform this to plain text?
        else
          raise "After reading METADATA headers, extra data is in the file but was not expected. This may be a bug in fpm."
        end
      end

      return headers
    rescue => e
      puts "String scan failed: #{e}"
      puts "Position: #{s.pointer}"
      puts "---"
      puts input
      puts "==="
      puts input[s.pointer...]
      puts "---"
      raise e
    end

    module_function :from

  end

  # Input a package.
  #
  # The 'package' can be any of:
  #
  # * A name of a package on pypi (ie; easy_install some-package)
  # * The path to a directory containing setup.py
  # * The path to a setup.py
  def input(package)
    explore_environment

    path_to_package = download_if_necessary(package, version)

    # Expect a setup.py or pypackage.toml if it's a directory.
    if File.directory?(path_to_package)
      if !(File.exist?(File.join(path_to_package, "setup.py")) or File.exist?(File.join(path_to_package, "pypackage.toml")))
        logger.error("The path doesn't appear to be a python package directory. I expected either a pypackage.toml or setup.py but found neither.", :package => package)
        raise "Unable to find python package; tried #{setup_py}"
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
    else File.directory?(path_to_package)
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

      files = ::Dir.glob(File.join(target, "*.{whl,tar.gz,zip}"))
      if files.length != 1
        raise "Unexpected directory layout after `pip download ...`. This might be an fpm bug? The directory contains these files: #{files.inspect}"
      end
      return files.first
    else
      # no pip, use easy_install
      logger.debug("no pip, defaulting to easy_install", :easy_install => attributes[:python_easyinstall])
      safesystem(attributes[:python_easyinstall], "-i",
                 attributes[:python_pypi], "--editable", "-U",
                 "--build-directory", target, want_pkg)
      # easy_install will put stuff in @tmpdir/packagename/, so find that:
      #  @tmpdir/somepackage/setup.py
      dirs = ::Dir.glob(File.join(target, "*"))
      if dirs.length != 1
        raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{build_path}"
      end
      return dirs.first
    end
  end # def download

  # Load the package information like name, version, dependencies.
  def load_package_info(path)
    if !attributes[:python_package_prefix].nil?
      attributes[:python_package_name_prefix] = attributes[:python_package_prefix]
    end

    if path.end_with?(".whl")
      # XXX: Maybe use rubyzip to parse the .whl (zip) file instead?
      metadata = nil
      execmd(["unzip", "-p", path, "*.dist-info/METADATA"], :stdin => false, :stderr => false) do |stdout|
        metadata = PythonMetadata.from(stdout.read(64<<10))
      end

      wheeldata = nil
      execmd(["unzip", "-p", path, "*.dist-info/WHEEL"], :stdin => false, :stderr => false) do |stdout|
        wheeldata = PythonMetadata.from(stdout.read(64<<10))
      end
    else
      raise "Unexpected python package path. This might be an fpm bug? The path is #{path}"
    end

    #self.architecture = metadata["architecture"]
    self.architecture = wheeldata["Root-Is-Purelib"] == "true" ? "all" : "native"
    self.description = metadata["Description"]

    if metadata["License"]
      self.license = metadata["License"]
    end

    self.version = metadata["Version"]

    if metadata["Project-URL"].is_a?(Array) && metadata["Project-URL"].any?
      self.url = metadata["Project-URL"].find(metadata["Project-URL"].method(:first)) do |entry|
        entry.start_with?("Homepage,")
      end.split(/, */, 2).last
    end

    self.name = metadata["Name"]

    # name prefixing is optional, if enabled, a name 'foo' will become
    # 'python-foo' (depending on what the python_package_name_prefix is)
    self.name = fix_name(self.name) if attributes[:python_fix_name?] 

    # convert python-Foo to python-foo if flag is set
    self.name = self.name.downcase if attributes[:python_downcase_name?]

    self.maintainer = metadata["Maintainer-Email"] unless metadata["Maintainer-Email"].nil?

    if !attributes[:no_auto_depends?] and attributes[:python_dependencies?]
      sys_platform = nil
      execmd([attributes[:python_bin], "-c", "import sys; print(sys.platform)"], :stdin => false, :stderr => false) do |stdout|
        sys_platform = stdout.read.chomp
      end

      dep_re = /^([^<>!= ]+)\s*(?:([~<>!=]{1,2})\s*(.*))?$/

      # Requires-Dist: name>=version; environment marker
      # Example:
      # Requires-Dist: tzdata; sys_platform = win32
      # Requires-Dist: asgiref>=3.8.1

      metadata["Requires-Dist"].each do |dep|
        dep, environment = dep.split(/ *; */)
        match = dep_re.match(dep)
        if match.nil?
          logger.error("Unable to parse dependency", :dependency => dep)
          raise FPM::InvalidPackageConfiguration, "Invalid dependency '#{dep}'"
        end

        if environment && environment.include?("sys_platform ==") && !environment.include?("sys_platform == #{sys_platform}")
          logger.info("Ignoring dependency because it doesn't match the current platform", :current => sys_platform, :target => environment, :dependency => dep)
          next
        end

        if environment && environment.include?("extra ==")
          logger.info("Ignoring extra/optional dependency", :dependency => dep, :extra => environment)
          next
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

        self.dependencies << "#{name} #{cmp} #{version}"
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
