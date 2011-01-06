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

    get_metadata

    # override the inferred data with the passed-in data
    params.each do |k,v|
      self[k] = v
    end

  end

  # this method should take the paths and root and infer as much
  # about the package as it can.
  def get_metadata
    raise NoMethodError,
      "Please subclass FPM::Source and define get_metadata"
  end

  def make_tarball!(tar_path)
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

  # make the binding public for erb templating
  def render(template)
    template.result(binding)
  end

private
  def tar(output, paths)
    dirs = []
    paths.each do |path|
      while path != "/" and path != "."
        dirs << path if !dirs.include?(path) 
        path = File.dirname(path)
      end
    end # paths.each
    system(*["tar", "--owner=root", "--group=root", "-cf", output, "--no-recursion", *dirs]) if dirs.any?
    system(*["tar", "--owner=root", "--group=root", "-rf", output, *paths])
  end # def tar
end
