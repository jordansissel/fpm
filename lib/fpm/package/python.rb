require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

class FPM::Package::Python < FPM::Package
  option "--bin", "PYTHON_EXECUTABLE",
    "The path to the python executable you wish to run.", :default => "python"
  option "--easyinstall", "EASYINSTALL_EXECUTABLE",
    "The path to the easy_install executable tool", :default => "easy_install"
  option "--pypi", "PYPI_URL",
    "PyPi Server uri for retrieving packages.",
    :default => "http://pypi.python.org/simple"
  option "--package-prefix", "PREFIX",
    "Name prefix for python package", :default => "python"

  def input(package)
    path_to_package = download_if_necessary(package, version)

    if File.directory?(path_to_package)
      setup_py = File.join(path_to_package, "setup.py")
    else
      setup_py = path_to_package
    end

    if !File.exists?(setup_py)
      @logger.error("Could not find 'setup.py'", :path => setup_py)
      raise "Unable to find python package; tried #{setup_py}"
    end

    load_package_info(setup_py)
    install_to_staging(setup_py)
  end # def input

  def download_if_necessary(package, version=nil)
    path = package
    # If it's a path, assume local build.
    if File.directory?(path) or (File.exists?(path) and File.basename(path) == "setup.py")
      return path
    end

    @logger.info("Trying to download", :package => package)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end

    target = build_path(package)
    FileUtils.mkdir(target) unless File.directory?(target)

    # TODO(sissel): support a settable path to 'easy_install'
    # TODO(sissel): support a tunable for uthe url to pypi
    safesystem("easy_install", "-i", "http://pypi.python.org/simple",
               "--editable", "-U", "--build-directory", target, want_pkg)

    # easy_install will put stuff in @tmpdir/packagename/, so find that:
    #  @tmpdir/somepackage/setup.py
    dirs = ::Dir.glob(File.join(target, "*"))
    if dirs.length != 1
      raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{build_path}"
    end
    return dirs.first
  end # def download

  def load_package_info(setup_py)
    if !attributes.include?(:package_name_prefix)
      attributes[:package_name_prefix] = "python"
    end

    # Add ./pyfpm/ to the python library path
    pylib = File.expand_path(File.dirname(__FILE__))
    setup_cmd = "env PYTHONPATH=#{pylib} #{self.attributes[:python_bin]} #{setup_py} --command-packages=pyfpm get_metadata"
    output = ::Dir.chdir(File.dirname(setup_py)) { `#{setup_cmd}` }
    puts output
    metadata = JSON.parse(output[/\{.*\}/msx])

    self.architecture = metadata["architecture"]
    self.description = metadata["description"]
    self.license = metadata["license"]
    self.version = metadata["version"]
    self.url = metadata["url"]

    self.name = fix_name(metadata["name"])

    self.dependencies += metadata["dependencies"].collect do |dep|
      name, cmp, version = dep.split
      name = fix_name(name)
      "#{name} #{cmp} #{version}"
    end
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
      return [attributes[:package_name_prefix], name.gsub(/^python-/, "")].join("-")
    else
      return [attributes[:package_name_prefix], name].join("-")
    end
  end # def fix_name

  def install_to_staging(setup_py)
    dir = File.dirname(setup_py)

    # Some setup.py's assume $PWD == current directory of setup.py, so let's
    # chdir first.
    ::Dir.chdir(dir) do
      if attributes[:prefix]
        safesystem(attributes[:python_bin], "setup.py", "install", "--prefix",
                   File.join(staging_path, attributes[:prefix]))
      else
        safesystem(attributes[:python_bin], "setup.py", "install", "--root",
                   staging_path)
      end
    end
  end # def install_to_staging
end # class FPM::Package::Python
