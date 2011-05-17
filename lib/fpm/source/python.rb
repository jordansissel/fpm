require "fpm/namespace"
require "fpm/source"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "tmpdir"
require "json"

class FPM::Source::Python < FPM::Source
  def get_source(params)
    package = @paths.first
    if ["setup.py", "."].include?(package)
      # Assume we're building from an existing python package.
      # Source already acquired, nothing to do!
      return
    end

    if !File.exists?(package) 
      download(package, params[:version])
    end
  end # def get_source

  def download(package, version=nil)
    puts "Trying to download #{package} (using easy_install)"
    @tmpdir = ::Dir.mktmpdir("python-build", ::Dir.pwd)

    if version.nil?
      want_pkg = "#{package}"
    else
      want_pkg = "#{package}==#{version}"
    end
    system("easy_install", "--editable", "--build-directory", @tmpdir, want_pkg)

    # easy_install will put stuff in @tmpdir/packagename/, flatten that.
    #  That is, we want @tmpdir/setup.py, and start with
    #  @tmpdir/somepackage/setup.py
    dirs = ::Dir.glob(File.join(@tmpdir, "*"))
    if dirs.length != 1
      raise "Unexpected directory layout after easy_install. Maybe file a bug? The directory is #{@tmpdir}"
    end
    @paths = dirs
  end # def download

  def get_metadata
    setup_py = @paths.first
    if File.directory?(setup_py)
      setup_py = File.join(setup_py, "setup.py")
      @paths = [setup_py]
    end

    if !File.exists?(setup_py)
      raise "Unable to find python package; tried #{setup_py}"
    end

    pylib = File.expand_path(File.dirname(__FILE__))
    setup_cmd = "env PYTHONPATH=#{pylib} python #{setup_py} --command-packages=pyfpm get_metadata"
    output = ::Dir.chdir(File.dirname(setup_py)) { `#{setup_cmd}` }
    puts output
    metadata = JSON.parse(output[/\{.*\}/msx])
    #p metadata

    self[:architecture] = metadata["architecture"]
    self[:description] = metadata["description"]
    self[:license] = metadata["license"]
    self[:version] = metadata["version"]
    self[:name] = "python#{self[:suffix]}-#{metadata["name"]}"
    self[:url] = metadata["url"]

    self[:dependencies] = metadata["dependencies"].collect do |dep|
      name, cmp, version = dep.split
      "python#{self[:suffix]}-#{name} #{cmp} #{version}"
    end
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    setup_py = @paths.first
    dir = File.dirname(setup_py)

    # Some setup.py's assume $PWD == current directory of setup.py, so let's
    # chdir first.
    ::Dir.chdir(dir) do
      system("python", "setup.py", "bdist")
    end

    dist_tar = ::Dir.glob(File.join(dir, "dist", "*.tar.gz")).first
    puts "Found dist tar: #{dist_tar}"
    puts "Copying to #{tar_path}"

    @paths = [ "." ]

    system("cp", dist_tar, "#{tar_path}.gz")
  end # def make_tarball!

  def garbage
    trash = []
    trash << @tmpdir if @tmpdir
    return trash
  end # def garbage

end # class FPM::Source::Gem
