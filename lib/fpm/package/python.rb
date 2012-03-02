require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

class FPM::Package::Python < FPM::Package
  def self.flags(opts, settings)
    settings.source[:python] = "python"
    settings.source[:easy_install] = "easy_install"
    settings.source[:pypi] = "http://pypi.python.org/simple"

    opts.on("--bin PYTHON_BINARY_LOCATION",
            "The path to the python you want to run. Default is 'python'") do |path|
      settings.source[:python] = path
    end

    opts.on("--easyinstall EASY_INSTALL_PATH",
            "The path to your easy_install tool. Default is 'easy_install'") do |path|
      settings.source[:easy_install] = path
    end

    opts.on("--pypi PYPI_SERVER",
            "PyPi Server uri for retrieving packages. Default is 'http://pypi.python.org/simple'") do |pypi|
      settings.source[:pypi] = pypi
    end

    opts.on("--package-prefix PREFIX",
            "Prefix for python packages") do |package_prefix|
      settings.source[:package_prefix] = package_prefix
    end
  end # def flags

  def input(package)
    path_to_package = download_if_necessary(package, version)
    load_package_info(path_to_package)
    install_to_staging(path_to_package)
  end # def input

  def download_if_necessary(package, version=nil)
    path = package
    # If it's a path, assume local build.
    if File.directory?(path) or (File.exists?(path) and File.basename(path) == "setup.py")
      return path
    end

    @logger.info("Trying to download", :package => package)
    @tmpdir = ::Dir.mktmpdir("python-build", ::Dir.pwd)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end

    # TODO(sissel): support a settable path to 'easy_install'
    # TODO(sissel): support a tunable for uthe url to pypi
    safesystem("easy_install", "-i", "http://pypi.python.org/simple",
               "--editable", "-U", "--build-directory", @tmpdir, want_pkg)

    # easy_install will put stuff in @tmpdir/packagename/, so find that:
    #  @tmpdir/somepackage/setup.py
    dirs = ::Dir.glob(File.join(@tmpdir, "*"))
    if dirs.length != 1
      raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{@tmpdir}"
    end
    return dirs.first
  end # def download

  def load_package_info(package_path)
    if File.directory?(setup_py)
      package_path = File.join(setup_py, "setup.py")
    end

    if !File.exists?(setup_py)
      @logger.error("Could not find 'setup.py'", :path => package_path)
      raise "Unable to find python package; tried #{setup_py}"
    end

    if !attributes.include?(:package_name_prefix)
      attributes[:package_name_prefix] = "python"
    end

    pylib = File.expand_path(File.dirname(__FILE__))
    setup_cmd = "env PYTHONPATH=#{pylib} #{self[:settings][:python]} #{setup_py} --command-packages=pyfpm get_metadata"
    output = ::Dir.chdir(File.dirname(setup_py)) { `#{setup_cmd}` }
    puts output
    metadata = JSON.parse(output[/\{.*\}/msx])

    self.architecture = metadata["architecture"]
    self.description = metadata["description"]
    self.license = metadata["license"]
    self.version = metadata["version"]
    self.url = metadata["url"]

    # Sanitize package name.
    # Some PyPI packages can be named 'python-foo', so we don't want to end up
    # with a package named 'python-python-foo'.
    # But we want packages named like 'pythonweb' to be suffixed
    # 'python-pythonweb'.
    self.name = fix_name(metadata["name"])

    self[:dependencies] += metadata["dependencies"].collect do |dep|
      name, cmp, version = dep.split
      name = fix_name(name)
      "#{name} #{cmp} #{version}"
    end
  end # def load_package_info

  def fix_name(name)
    if name.start_with?("python")
      # If the python package is called "python-foo" strip the "python-" part while
      # prepending the package name prefix.
      return [attributes[:package_name_prefix], name.gsub(/^python-/, "")].join("-")
    else
      return [attributes[:package_name_prefix], name].join("-")
    end
  end # def fix_name

  def install_to_staging(package_path)
    dir = File.dirname(package_path)

    # Some setup.py's assume $PWD == current directory of setup.py, so let's
    # chdir first.
    ::Dir.chdir(dir) do
      # TODO(sissel): Make the path to 'python' tunable
      # TODO(sissel): Respect '--prefix' somewhow from the caller?
      safesystem("python", "setup.py", "install", "--prefix", staging_path)
    end
    clean
  end # def make_tarball!

  def clean
    FileUtils.rm_r(@tmpdir)
  end # def clean
end # class FPM::Package::Python
