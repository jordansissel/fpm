require "fpm/namespace"
require "fpm/util"

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
  ).each do |attr|
    attr = :"#{attr}"
    define_method(attr) { self[attr] }
    define_method(:"#{attr}=") { |v| self[attr] = v}
  end

  def dependencies
    self[:dependencies] ||= []
  end

  attr_reader :paths
  attr_accessor :root

  def initialize(paths, root, params={})
    @logger = Logger.new(STDERR)
    @logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

    @paths = paths
    @root = root

    self[:suffix] = params[:suffix]
    self[:settings] = params[:settings]

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


    # Solaris's tar is pretty neutered, so implement --exclude and such
    # ourselves.
    # TODO(sissel): May need to implement our own tar file generator
    # so we can enforce file ownership. Again, solaris' tar doesn't support
    # --owner, etc.
    #paths = []
    #dirs.each do |dir|
      #Dir.glob(File.join(dir, "**", "*")).each do |path|
        #next if excludesFile.fnmatch?(
      #end
    #end

    excludes = self[:exclude].map { |e| ["--exclude", e] }.flatten

    # TODO(sissel): To properly implement excludes as regexps, we
    # will need to find files ourselves. That may be more work
    # than it is worth. For now, rely on tar's --exclude.
    dir_tar = [tar_cmd, "--owner=root", "--group=root" ] \
              + excludes \
              + ["-cf", output, "--no-recursion" ] \
              + dirs

    ::Dir.chdir(chdir) do
      safesystem(*dir_tar) if dirs.any?
    end

    files_tar = [ tar_cmd ] \
                + excludes \
                + [ "--owner=root", "--group=root", "-rf", output ] \
                + paths
    ::Dir.chdir(chdir) do
      safesystem(*files_tar)
    end
  end # def tar

  def tar_cmd
    # Rely on gnu tar for solaris.
    case %x{uname -s}.chomp
    when "SunOS"
      return "gtar"
    else
      return "tar"
    end
  end # def tar_cmd
end # class FPM::Source
