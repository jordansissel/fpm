require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

# Support for python virtualenv packages.
#
# This supports input, but not output.
#
# Example:
#
#     # Download the django python package:
#     pkg = FPM::Package::Python.new
#     pkg.input("Django")
#
class FPM::Package::Virtualenv < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:python_foo]
  option "--pypi", "PYPI_URL",
  "PyPi Server uri for retrieving packages.",
  :default => "https://pypi.python.org/simple"
  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
  "name with.", :default => "virtualenv"
  option "--fix-name", :flag, "Should the target package name be prefixed?",
  :default => true
  option "--install-folder", "BIN_PATH", "The path to where python scripts " \
  "should be installed to.", :default => "/usr/share/python"
  option "--other-files-directory", "DIRECTORY", "Optionally, the contents of the " \
  "specified directory may be added to the package.", :default => nil

  private

  # Input a package.
  #
  def input(package)
    m = /^([^=]+)==([^=]+)$/.match(package)
    package_version = nil
    if m
      self.name ||= m[1]
      self.version ||= m[2]
      package = m[1]
      package_version = m[2]
    else
      self.name ||= package
    end

    if self.attributes[:virtualenv_fix_name?]
      self.name = [self.attributes[:virtualenv_package_name_prefix],
                   self.name].join("-")
    end

    virtualenv_folder =
      File.join(attributes[:virtualenv_install_folder],
                package)
    virtualenv_build_folder = build_path(virtualenv_folder)

    ::FileUtils.mkdir_p(virtualenv_build_folder)

    safesystem("virtualenv", virtualenv_build_folder)
    pip_exe = File.join(virtualenv_build_folder, "bin", "pip")
    python_exe = File.join(virtualenv_build_folder, "bin", "python")

    # Why is this hack here? It looks important, so I'll keep it in.
    safesystem(pip_exe, "install", "-U", "-i",
               attributes[:virtualenv_pypi],
               "pip", "distribute")
    safesystem(pip_exe, "uninstall", "-y", "distribute")

    safesystem(pip_exe, "install", "-i",
               attributes[:virtualenv_pypi],
               package)

    if package_version.nil?
      frozen = safesystemout(pip_exe, "freeze")
      package_version = frozen[/#{package}==[^=]+$/].split("==")[1].chomp!
      self.version ||= package_version
    end

    ::Dir[build_path + "/**/*"].each do |f|
      if ! File.world_readable? f
        File.lchmod(File.stat(f).mode | 444)
      end
    end

    ::Dir.chdir(virtualenv_build_folder) do
      safesystem("virtualenv-tools", "--update-path", virtualenv_folder)
    end

    if !attributes[:virtualenv_other_files_directory].nil?
      ::Dir.foreach(attributes[:virtualenv_other_files_directory]) do |i|
        next if i == '.' or i == '..'
        copy_entry(File.join(attributes[:virtualenv_other_files_directory], i),
                   build_path(i))
      end
    end

    logger.debug("Now removing python object and compiled files from the virtualenv")

    ::Dir[build_path + "/**/*.pyo"].each do |f|
      ::FileUtils.rm_f(f)
    end

    ::Dir[build_path + "/**/*.pyc"].each do |f|
      ::FileUtils.rm_f(f)
    end

    # use dir to set stuff up properly, mainly so I don't have to reimplement
    # the chdir/prefix stuff special for tar.
    dir = convert(FPM::Package::Dir)
    if attributes[:chdir]
      dir.attributes[:chdir] = File.join(build_path, attributes[:chdir])
    else
      dir.attributes[:chdir] = build_path
    end
    cleanup_staging
    # Tell 'dir' to input "." and chdir/prefix will help it figure out the
    # rest.
    dir.input(".")
    @staging_path = dir.staging_path
    dir.cleanup_build
  end # def input

  public(:input)
end # class FPM::Package::Python
