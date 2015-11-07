require "fpm/namespace"
require "fpm/package"
require "fpm/util"

# Support for python virtualenv packages.
#
# This supports input, but not output.
#
class FPM::Package::Virtualenv < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:virtualenv_foo]

  option "--pypi", "PYPI_URL",
  "PyPi Server uri for retrieving packages.",
  :default => "https://pypi.python.org/simple"
  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
  "name with.", :default => "virtualenv"

  option "--install-location", "DIRECTORY", "Location to which to " \
  "install the virtualenv by default.", :default => "/usr/share/python" do |path|
    File.expand_path(path)
  end

  option "--fix-name", :flag, "Should the target package name be prefixed?",
  :default => true
  option "--other-files-dir", "DIRECTORY", "Optionally, the contents of the " \
  "specified directory may be added to the package. This is useful if the " \
  "virtualenv needs configuration files, etc.", :default => nil
  option "--pypi-extra-url", "PYPI_EXTRA_URL",
    "PyPi extra-index-url for pointing to your priviate PyPi",
    :multivalued => true, :attribute_name => :virtualenv_pypi_extra_index_urls,
    :default => nil

  private

  # Input a package.
  #
  #     `package` can look like `psutil==2.2.1` or `psutil`.
  def input(package)
    installdir = attributes[:virtualenv_install_location]
    m = /^([^=]+)==([^=]+)$/.match(package)
    package_version = nil

    if m
      package_name = m[1]
      package_version = m[2]
      self.version ||= package_version
    else
      package_name = package
      package_version = nil
    end

    virtualenv_name = package_name

    self.name ||= package_name

    if self.attributes[:virtualenv_fix_name?]
      self.name = [self.attributes[:virtualenv_package_name_prefix],
                   self.name].join("-")
    end

    virtualenv_folder =
      File.join(installdir,
                virtualenv_name)

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

    extra_index_url_args = []
    if attributes[:virtualenv_pypi_extra_index_urls]
      attributes[:virtualenv_pypi_extra_index_urls].each do |extra_url|
        extra_index_url_args << "--extra-index-url" << extra_url
      end
    end
    pip_args = [pip_exe, "install", "-i", attributes[:virtualenv_pypi]] << extra_index_url_args << package
    safesystem(*pip_args.flatten)

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

    if !attributes[:virtualenv_other_files_dir].nil?
      # Copy all files from other dir to build_path
      Find.find(attributes[:virtualenv_other_files_dir]) do |path|
        src = path.gsub(/^#{attributes[:virtualenv_other_files_dir]}/, '')
        dst = File.join(build_path, src)
        copy_entry(path, dst, preserve=true, remove_destination=true)
        copy_metadata(path, dst)
      end
    end

    remove_python_compiled_files virtualenv_build_folder

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

  # Delete python precompiled files found in a given folder.
  def remove_python_compiled_files path
    logger.debug("Now removing python object and compiled files from the virtualenv")
    Find.find(path) do |path|
      if path.end_with? '.pyc' or path.end_with? '.pyo'
        FileUtils.rm path
      end
    end
  end
  public(:input)
end # class FPM::Package::Virtualenv
