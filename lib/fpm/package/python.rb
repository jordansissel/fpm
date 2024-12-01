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
  option "--build-backend-arguments", "build_backend_argument",
         "Arbitrary argument(s) to be passed to pep517 build backend",
         :multivalued => true, :attribute_name => :python_build_backend_arguments,
         :default => []
  option "--internal-pip", :flag,
    "Use the pip module within python to install modules - aka 'python -m pip'. This is the recommended usage since Python 3.4 (2014) instead of invoking the 'pip' script",
    :attribute_name => :python_internal_pip,
    :default => true

  private

  PY_PACKAGE_TYPE = {
    unspecified: 0,
    setup_py: 1,
    pyproject_toml: 2,
    wheel: 3,
  }

  def guess_py_pack_type(path)
    if File.file?(path)
      if File.basename(path) == "setup.py"
        return PY_PACKAGE_TYPE[:setup_py]
      elsif File.basename(path) == "pyproject.toml"
        return PY_PACKAGE_TYPE[:pyproject_toml]
      elsif File.extname(path) == ".whl"
        return PY_PACKAGE_TYPE[:wheel]
      end
    end
    return PY_PACKAGE_TYPE[:unspecified]
  end #def guess_py_pack_type(path)

  # Input a package.
  #
  # The 'package' can be any of:
  #
  # * A name of a package on pypi (ie; easy_install some-package)
  # * The path to a directory containing pyproject.toml
  # * The path to a directory containing setup.py
  # * ? @todo The path to a directory containing Wheel file (*.whl)
  # * The path to a pyproject.toml
  # * The path to a setup.py
  # * The path to a Wheel file (*.whl)
  def input(package)
    path_to_package = download_if_necessary(package, version)
    package_type = PY_PACKAGE_TYPE[:unspecified]

    if File.file?(path_to_package)
      package_type = guess_py_pack_type(path_to_package)
    elsif File.directory?(path_to_package)
      files = ::Dir.glob(File.join(path_to_package, "*.whl"))
      if files.length == 1
        # 			package_type = guess_py_pack_type(File.join(path_to_package, files.first))
        package_type = PY_PACKAGE_TYPE[:wheel]
        path_to_package = files.first
      elsif files.length > 1
        raise "Must be only one *.whl file! The directory is #{path_to_package}"
      else
        package_type = guess_py_pack_type(File.join(path_to_package, "pyproject.toml"))
        if package_type != PY_PACKAGE_TYPE[:unspecified]
          path_to_package = File.join(path_to_package, "pyproject.toml")
        else
          package_type = guess_py_pack_type(File.join(path_to_package, "setup.py"))
          if package_type != PY_PACKAGE_TYPE[:unspecified]
            path_to_package = File.join(path_to_package, "setup.py")
          else
            raise "Unable to guess package type in #{path_to_package}"
          end
        end
      end
    end

    if package_type == PY_PACKAGE_TYPE[:unspecified]
      logger.error("Could not find neither 'setup.py' nor 'pyproject.toml' nor '*.whl'", :path => path_to_package)
      raise "Unable to find python package; tried #{setup_py} and #{pyproject_toml} (*.whl NYI)"
    elsif package_type == PY_PACKAGE_TYPE[:wheel]
      logger.debug("Do job with *.whl file")
      #      raise "Unable to create python package due to wrong hands curvature (NYI)"
    elsif package_type == PY_PACKAGE_TYPE[:pyproject_toml]
      logger.debug("Do job with pyproject.toml")
      path_to_package = build_py_wheel(path_to_package)
    elsif package_type == PY_PACKAGE_TYPE[:setup_py]
      logger.debug("Do job with setup.py")
    else
      logger.error("Complete enum!", :path => path_to_package)
      raise "Unable to create python package due to wrong hands curvature"
    end

    load_package_info(path_to_package, package_type)

    if package_type == PY_PACKAGE_TYPE[:pyproject_toml]
      logger.debug("Complete job with pyproject.toml")
    elsif package_type == PY_PACKAGE_TYPE[:setup_py]
      logger.debug("Complete job with setup.py")
    elsif package_type == PY_PACKAGE_TYPE[:wheel]
      logger.debug("Complete job with wheel file")
    else
      logger.error("NYI", :path => path_to_package)
      raise "Unable to create python package due to wrong hands curvature (NYI)"
    end

    install_to_staging(path_to_package, package_type)
  end # def input

  # Download the given package if necessary. If version is given, that version
  # will be downloaded, otherwise the latest is fetched.
  def download_if_necessary(package, version = nil)
    # TODO(sissel): this should just be a 'download' method, the 'if_necessary'
    # part should go elsewhere.
    path = package
    # If it's a path, assume local build.
    if File.directory?(path) or (File.exist?(path) and (File.basename(path) == "setup.py" or File.basename(path) == "pyproject.toml" or File.extname(path) == ".whl"))
      return path
    end

    logger.info("Trying to download", :package => package)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end

    target = build_path(package)
    FileUtils.mkdir(target) unless File.directory?(target)

    if attributes[:python_internal_pip?]
      # XXX: Should we detect if internal pip is available?
      attributes[:python_pip] = [attributes[:python_bin], "-m", "pip"]
    end

    # attributes[:python_pip] -- expected to be a path
    if attributes[:python_pip]
      logger.debug("using pip", :pip => attributes[:python_pip])
      # TODO: Support older versions of pip

      pip = [attributes[:python_pip]] if pip.is_a?(String)
      setup_cmd = [
        *attributes[:python_pip],
        "download",
        "--no-clean",
        "--no-deps",
        "--disable-pip-version-check",
        "--no-python-version-warning",
        "--prefer-binary",
        #        "--no-binary", ":all:",
        "--dest", build_path,
        "--index-url", attributes[:python_pypi],
      ]

      if attributes[:python_trusted_host]
        setup_cmd += [
          "--trusted-host",
          attributes[:python_trusted_host],
        ]
      end

      setup_cmd << want_pkg

      safesystem(*setup_cmd)

      # Pip removed the --build flag sometime in 2021, it seems: https://github.com/pypa/pip/issues/8333
      # A workaround for pip removing the `--build` flag. Previously, `pip download --build ...` would leave
      # behind a directory with the Python package extracted and ready to be used.
      # For example, `pip download ... Django` puts `Django-4.0.4.tar.tz` into the build_path directory.
      # If we expect `pip` to leave an unknown-named file in the `build_path` directory, let's check for
      # a single file and unpack it.  I don't know if it will /always/ be a .tar.gz though.
      files = ::Dir.glob(File.join(build_path, "*.whl"))
      if files.length == 1
        FileUtils.cp(files.first, target)
      else
        files = ::Dir.glob(File.join(build_path, "*.tar.gz"))
        if files.length != 1
          raise "Unexpected directory layout after `pip download ...`. This might be an fpm bug? The directory is #{build_path}"
        end

        safesystem("tar", "-zxf", files.first, "-C", target)
      end
    else
      # no pip, use easy_install
      logger.debug("no pip, defaulting to easy_install", :easy_install => attributes[:python_easyinstall])
      safesystem(attributes[:python_easyinstall], "-i",
                 attributes[:python_pypi], "--editable", "-U",
                 "--build-directory", target, want_pkg)
    end

    # easy_install will put stuff in @tmpdir/packagename/, so find that:
    #  @tmpdir/somepackage/setup.py
    dirs = ::Dir.glob(File.join(target, "*"))
    if dirs.length != 1
      raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{build_path}"
    end
    return dirs.first
  end # def download

  # Build Python wheel file (*.whl).
  def build_py_wheel(setup_data)
    project_dir = File.dirname(setup_data)

    prefix = "/"
    prefix = attributes[:prefix] unless attributes[:prefix].nil?

    wheel_dir = ".fpm-wheel"
    # Some assume $PWD == current directory of package, so let's
    # chdir first.
    ::Dir.chdir(project_dir) do

      # @todo FIXME!!! - is it necessary?
      #      flags = [ "--python", attributes[:python_bin] ]
      flags = []

      # @todo FIXME!!!
      # pip wheel:
      # no such option: --prefix
      # Should we revert to install to staging not from wheel, but from original source dist?
      # if !attributes[:prefix].nil?
      #   flags += [ "--prefix", attributes[:prefix] ]
      # else
      #   flags += ["--prefix", "/usr/local/"]
      # end

      flags += ["--wheel-dir", wheel_dir]
      flags += ["--no-input"]
      flags += ["--disable-pip-version-check"]
      flags += ["--no-python-version-warning"]
      #      flags += [ "--verbose --verbose --verbose"]
      opt = "w"  # w == wipe
      flags += ["--exists-action", opt]
      # @todo FIXME!!! is it really necessary?
      flags += ["--no-cache-dir"]
      opt = "off"
      flags += ["--progress-bar", opt]
      flags += ["--no-deps"]
      flags += ["--use-pep517"]
      flags += ["--check-build-dependencies"]

      # @todo FIXME!!! --config-settings for PEP 517 build backend (KEY=VALUE, can be multiple)
      # I have no clue where to get all that 'options' and any description of possible 'backends'
      if !attributes[:python_build_backend_arguments].nil? and !attributes[:python_build_backend_arguments].empty?
        # Add optional arguments for pep517 build backend
        attributes[:python_build_backend_arguments].each do |a|
          flags += ["--config-settings", a]
        end
      end

      safesystem(*attributes[:python_pip], "wheel", ".", *flags)
    end

    files = ::Dir.glob(File.join(project_dir, wheel_dir, "*.whl"))
    if files.length != 1
      raise "Unexpected directory layout after `pip wheel ...`. This might be an fpm bug? The directory is #{build_path}"
    end

    return files.first
  end # def build_py_wheel

  # Load the package information like name, version, dependencies.
  def load_package_info(package_data, package_type)
    if !attributes[:python_package_prefix].nil?
      attributes[:python_package_name_prefix] = attributes[:python_package_prefix]
    end

    # Add ./pyfpm/ to the python library path
    pylib = File.expand_path(File.dirname(__FILE__))

    # chdir to the directory holding setup.py because some python setup.py's assume that you are
    # in the same directory.
    logger.error(package_data)
    setup_dir = File.dirname(package_data)

    if package_type == PY_PACKAGE_TYPE[:unspecified]
      logger.error("Can not guess package setup type.")
      raise FPM::Util::ProcessFailed, "Can not guess package setup type."
    elsif package_type == PY_PACKAGE_TYPE[:setup_py]
      begin
        json_test_code = [
          "try:",
          "  import json",
          "except ImportError:",
          "  import simplejson as json",
        ].join("\n")
        safesystem("#{attributes[:python_bin]} -c '#{json_test_code}'")
      rescue FPM::Util::ProcessFailed => e
        logger.error("Your python environment is missing json support (either json or simplejson python module). I cannot continue without this.", :python => attributes[:python_bin], :error => e)
        raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing simplejson or json modules."
      end

      begin
        safesystem("#{attributes[:python_bin]} -c 'import pkg_resources'")
      rescue FPM::Util::ProcessFailed => e
        logger.error("Your python environment is missing a working setuptools module. I tried to find the 'pkg_resources' module but failed.", :python => attributes[:python_bin], :error => e)
        raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing pkg_resources module."
      end

      logger.error(setup_dir)
      output = ::Dir.chdir(setup_dir) do
        tmp = build_path("metadata.json")
        get_metadata_cmd = "env PYTHONPATH=#{pylib}:$PYTHONPATH #{attributes[:python_bin]} " \
        "setup.py --command-packages=pyfpm get_metadata --output=#{tmp}"

        if attributes[:python_obey_requirements_txt?]
          get_metadata_cmd += " --load-requirements-txt"
        end

        # Capture the output, which will be JSON metadata describing this python
        # package. See fpm/lib/fpm/package/pyfpm/get_metadata.py for more
        # details.
        logger.info("fetching package metadata", :get_metadata_cmd => get_metadata_cmd)

        success = safesystem(get_metadata_cmd)

        if !success
          logger.error("setup.py get_metadata failed", :command => get_metadata_cmd,
                                                       :exitcode => $?.exitstatus)
          raise "An unexpected error occurred while processing the setup.py file"
        end
        File.read(tmp)
      end
    elsif package_type == PY_PACKAGE_TYPE[:pyproject_toml] or package_type == PY_PACKAGE_TYPE[:wheel]
      begin
        safesystem("#{attributes[:python_bin]} -c 'import json'")
      rescue FPM::Util::ProcessFailed => e
        logger.error("Your python environment is missing json support. I cannot continue without this.", :python => attributes[:python_bin], :error => e)
        raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing json module."
      end

      begin
        safesystem("#{attributes[:python_bin]} -c 'from pkginfo import Wheel'")
      rescue FPM::Util::ProcessFailed => e
        logger.error("Your python environment is missing a working pkginfo.Wheel module. I tried to find the 'importlib.Wheel' module but failed.", :python => attributes[:python_bin], :error => e)
        raise FPM::Util::ProcessFailed, "Python (#{attributes[:python_bin]}) is missing pkginfo.Wheel module."
      end

      output = ::Dir.chdir(setup_dir) do
        tmp = build_path("metadata.json")

        toml_metadata_code = [
          "from pyfpm_wheel import get_metadata_wheel",
          "gmt = get_metadata_wheel.get_metadata_wheel('#{package_data}')",
          "gmt.run('#{tmp}')",
        ].join("\n")

        get_metadata_cmd = "env PYTHONPATH=#{pylib}:$PYTHONPATH #{attributes[:python_bin]} " \
        " -c " \
        "#{Shellwords.escape(toml_metadata_code)}"

        # @todo FIXME!
        #      if attributes[:python_obey_requirements_txt?]
        #        setup_cmd += " --load-requirements-txt"
        #       end

        # Capture the output, which will be JSON metadata describing this python
        # package. See fpm/lib/fpm/package/pyfpm_wheel/get_metadata_wheel.py for more
        # details.
        logger.info("fetching package wheel metadata", :get_metadata_cmd => get_metadata_cmd)

        success = safesystem(get_metadata_cmd)

        if !success
          logger.error("pyfpm_wheel get_metadata failed", :command => get_metadata_cmd,
                                                          :exitcode => $?.exitstatus)
          raise "An unexpected error occurred while processing the wheel file"
        end
        File.read(tmp)
      end
    else
      logger.error("NYI", :path => setup_dir)
      raise "Unable to create python package due to wrong hands curvature (NYI)"
    end

    logger.debug("result from get_metadata", :data => output)
    metadata = JSON.parse(output)
    logger.info("object output of get_metadata", :json => metadata)

    self.architecture = metadata["architecture"]
    self.description = metadata["description"]
    # Sometimes the license field is multiple lines; do best-effort and just
    # use the first line.
    if metadata["license"]
      self.license = metadata["license"].split(/[\r\n]+/).first
    end

    if metadata["version"]
      self.version = metadata["version"]
    end

    if metadata["url"]
      self.url = metadata["url"]
    end

    if metadata["author"]
      self.vendor = metadata["author"]
    end

    # name prefixing is optional, if enabled, a name 'foo' will become
    # 'python-foo' (depending on what the python_package_name_prefix is)
    if attributes[:python_fix_name?]
      self.name = fix_name(metadata["name"])
    else
      self.name = metadata["name"]
    end

    # convert python-Foo to python-foo if flag is set
    self.name = self.name.downcase if attributes[:python_downcase_name?]

    if !attributes[:no_auto_depends?] and attributes[:python_dependencies?]
      metadata["dependencies"].each do |dep|
        dep_re = /^([^<>!= ]+)\s*(?:([~<>!=]{1,2})\s*(.*))?$/
        match = dep_re.match(dep)
        if match.nil?
          logger.error("Unable to parse dependency", :dependency => dep)
          raise FPM::InvalidPackageConfiguration, "Invalid dependency '#{dep}'"
        end
        name, cmp, version = match.captures

        next if attributes[:python_disable_dependency].include?(name)

        # convert == to =
        if cmp == "==" or cmp == "~="
          logger.info("Converting == dependency requirement to =", :dependency => dep)
          cmp = "="
        end

        # dependency name prefixing is optional, if enabled, a name 'foo' will
        # become 'python-foo' (depending on what the python_package_name_prefix
        # is)
        name = fix_name(name) if attributes[:python_fix_dependencies?]

        # convert dependencies from python-Foo to python-foo
        name = name.downcase if attributes[:python_downcase_dependencies?]

        self.dependencies << "#{name} #{cmp} #{version}"
      end
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
  def install_to_staging(package_data, package_type)
    project_dir = File.dirname(package_data)

    prefix = "/"
    prefix = attributes[:prefix] unless attributes[:prefix].nil?

    if package_type == PY_PACKAGE_TYPE[:unspecified]
      logger.error("Can not guess package setup type.")
      raise FPM::Util::ProcessFailed, "Can not guess package setup type."

      # Install this package to the staging directory via setup.py
    elsif package_type == PY_PACKAGE_TYPE[:setup_py]
      # Some setup.py's assume $PWD == current directory of setup.py, so let's
      # chdir first.
      ::Dir.chdir(project_dir) do
        flags = ["--root", staging_path]
        if !attributes[:python_install_lib].nil?
          flags += ["--install-lib", File.join(prefix, attributes[:python_install_lib])]
        elsif !attributes[:prefix].nil?
          # setup.py install --prefix PREFIX still installs libs to
          # PREFIX/lib64/python2.7/site-packages/
          # but we really want something saner.
          #
          # since prefix is given, but not python_install_lib, assume PREFIX/lib
          flags += ["--install-lib", File.join(prefix, "lib")]
        end

        if !attributes[:python_install_data].nil?
          flags += ["--install-data", File.join(prefix, attributes[:python_install_data])]
        elsif !attributes[:prefix].nil?
          # prefix given, but not python_install_data, assume PREFIX/data
          flags += ["--install-data", File.join(prefix, "data")]
        end

        if !attributes[:python_install_bin].nil?
          flags += ["--install-scripts", File.join(prefix, attributes[:python_install_bin])]
        elsif !attributes[:prefix].nil?
          # prefix given, but not python_install_bin, assume PREFIX/bin
          flags += ["--install-scripts", File.join(prefix, "bin")]
        end

        if !attributes[:python_scripts_executable].nil?
          # Overwrite installed python scripts shebang binary with provided executable
          flags += ["build_scripts", "--executable", attributes[:python_scripts_executable]]
        end

        if !attributes[:python_setup_py_arguments].nil? and !attributes[:python_setup_py_arguments].empty?
          # Add optional setup.py arguments
          attributes[:python_setup_py_arguments].each do |a|
            flags += [a]
          end
        end

        safesystem(attributes[:python_bin], "setup.py", "install", *flags)
      end

      # Install this package to the staging directory via wheel (possibly converted from pyproject.toml)
    elsif package_type == PY_PACKAGE_TYPE[:pyproject_toml] or package_type == PY_PACKAGE_TYPE[:wheel]
      # Some setup's assume $PWD == current directory of pyproject.toml, so let's
      # chdir first.
      ::Dir.chdir(project_dir) do
        flags = ["--root", staging_path]

        # if !attributes[:python_install_lib].nil?
        #   flags += [ "--prefix", attributes[:python_install_lib] ]
        # elsif !attributes[:prefix].nil?
        #   # since prefix is given, but not python_install_lib, assume PREFIX/lib
        #   flags += [ "--prefix", File.join(prefix, "lib") ]
        # end

        if !attributes[:python_install_lib].nil?
          # @todo FIXME!!! --target does really strange things...
          # When specified, all package content goes to /tmp in result deb.
          #flags += [ "--target", attributes[:python_install_lib] ]
          #
          # With --prefix things is not getting easier -
          # when --python-install-lib=/usr/local-mega/lib/python3.9/dist-packages/ specified
          # all package content goes to
          # /usr/local-mega/lib/python3.9/dist-packages/lib/python3.9/site-packages
          # in result deb.
          #flags += [ "--prefix", attributes[:python_install_lib] ]
        elsif !attributes[:prefix].nil?
          # since prefix is given, but not python_install_lib, assume PREFIX/lib
          flags += ["--prefix", File.join(prefix, "lib")]
        end

        opt = "off"
        flags += ["--progress-bar", opt]
        flags += ["--no-deps"]
        # Otherwise it'll complain on already installed distribution packages.
        # Why? Have no idea, since --root is always specified, it supposed to be safe.
        flags += ["--ignore-installed"]

        safesystem(*attributes[:python_pip], "install", *flags, package_data)
      end
    else
      logger.error("NYI", :path => path_to_package)
      raise "Unable to create python package due to wrong hands curvature (NYI)"
    end
  end # def install_to_staging

  public(:input)
end # class FPM::Package::Python
