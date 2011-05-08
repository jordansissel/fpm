require "fpm/namespace"

# Abstract class for a "thing to build a package from"
class FPM::Source
  # standard package metadata
  %w(
    name
    version
    iteration
    architecture
    maintainer
    category
    url
    description
    summary
  ).each do |attr|
    attr = :"#{attr}"
    define_method(attr) { self[attr] }
    define_method(:"#{attr}=") { |v| self[attr] = v}
  end

  def dependencies
    self[:dependencies] ||= []
  end

  attr_reader :paths
  attr_reader :root
  def initialize(paths, root, params={})
    @paths = paths
    @root = root

    self[:suffix] = params[:suffix]
    get_source(params)
    get_metadata

    # override the inferred data with the passed-in data
    params.each do |k,v|
      self[k] = v if v != nil
    end
  end # def initialize

  # this method should take the paths and root and infer as much
  # about the package as it can.
  def get_metadata
    raise NoMethodError,
      "Please subclass FPM::Source and define get_metadata"
  end # def get_metadata

  # This method should be overridden by package sources that need to do any
  # kind of fetching.
  def get_source(params)
    # noop by default
  end # def get_source

  def make_tarball!(tar_path, builddir)
    raise NoMethodError,
      "Please subclass FPM::Source and define make_tarball!(tar_path)"
  end

  def metadata
    @metadata ||= {}
  end

  def [](key)
    metadata[key.to_sym]
  end

  def []=(key,val)
    metadata[key.to_sym] = val
  end

  # MySourceClass.new('/tmp/build').package(FPM::Deb).assemble(params)
  def package(pkg_cls)
    pkg_cls.new(self)
  end

  private
  def tar(output, paths, chdir=".")
    dirs = []

    # Include all directory entries at the top of the tarball
    paths = [ paths ] if paths.is_a? String
    paths.each do |path|
      while path != "/" and path != "."
        dirs << path if !dirs.include?(path) 
        path = File.dirname(path)
      end
    end # paths.each
    
    # Want directories to be sorted thusly: [ "/usr", "/usr/bin" ]
    # Why? tar and some package managers sometimes fail if the tar is created
    # like: [ "/opt/fizz", "/opt" ]
    # dpkg -i will fail if /opt doesn't exist, sorting it by length ensures
    # /opt is created before /opt/fizz.
    dirs.sort! { |a,b| a.size <=> b.size }
    paths.sort! { |a,b| a.size <=> b.size }

    excludes = self[:exclude].map { |e| ["--exclude", e] }.flatten

    # TODO(sissel): To properly implement excludes as regexps, we
    # will need to find files ourselves. That may be more work
    # than it is worth. For now, rely on tar's --exclude.
    dir_tar = ["tar", "-C", chdir, "--owner=root", "--group=root" ] \
              + excludes \
              + ["-cf", output, "--no-recursion" ] \
              + dirs
    system(*dir_tar) if dirs.any?

    files_tar = [ "tar", "-C", chdir ] \
                + excludes \
                + [ "--owner=root", "--group=root", "-rf", output ] \
                + paths
    system(*files_tar)
  end # def tar
end
