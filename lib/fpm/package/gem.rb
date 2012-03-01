require "fpm/namespace"
require "fpm/package"
require "rubygems/package"
require "rubygems"
require "fileutils"
require "fpm/util"

# A rubygems package.
#
# This does not currently support 'output'
class FPM::Package::Gem < FPM::Package
  private
  def self.flags(opts, settings)
    settings.source[:gem] = "gem"

    opts.on("--bin-path DIRECTORY",
            "The directory to install gem executables") do |path|
      settings.source[:bin_path] = path
    end
    opts.on("--package-prefix PREFIX",
            "Prefix for gem packages") do |package_prefix|
      settings.source[:package_prefix] = package_prefix
    end

    opts.on("--gem PATH_TO_GEM",
            "The path to the 'gem' tool (defaults to 'gem' and searches " \
            "your $PATH)") do |path|
      settings.source[:gem] = path
    end
  end # def flags

  def input(gem)
    # 'arg'  is the name of the rubygem we should unpack.
    path_to_gem = download_if_necessary(gem, version)

    # Got a good gem now (downloaded or otherwise)
    #
    # 1. unpack it into staging_path
    # 2. take the metadata from it and update our wonderful package with it.
    load_package_info(path_to_gem)
    install_to_staging(path_to_gem)
  end # def input

  def download_if_necessary(gem, gem_version)
    path = gem
    if !File.exists?(path)
      looks_like_name_re = /^[A-Za-z0-9_-]+$/
      if path =~ looks_like_name_re
        path = download(gem, gem_version)
      else
        raise FPM::Package::InvalidArgument.new("Gem '#{gem}' doesn't appear to be a valid rubygem file or name?")
      end
    end

    @logger.info("Using gem file", :path => path)
    return path
  end # def download_if_necessary

  def download(gem_name, gem_version=nil)
    # This code mostly mutated from rubygem's fetch_command.rb
    # Code use permissible by rubygems's "GPL or these conditions below"
    # http://rubygems.rubyforge.org/rubygems-update/LICENSE_txt.html

    @logger.info("Trying to download", :gem => gem_name, :version => gem_version)
    dep = ::Gem::Dependency.new(gem_name, gem_version)

    # TODO(sissel): Make a flag to allow prerelease gems?
    #dep.prerelease = options[:prerelease]

    if ::Gem::SpecFetcher.fetcher.respond_to?(:fetch_with_errors)
      specs_and_sources, errors =
        ::Gem::SpecFetcher.fetcher.fetch_with_errors(dep, true, true, false)
    else
      specs_and_sources =
        ::Gem::SpecFetcher.fetcher.fetch(dep, true)
      errors = "???"
    end
    spec, source_uri = specs_and_sources.sort_by { |s,| s.version }.last

    if spec.nil? then
      @logger.error("Invalid gem?", :name => gem_name, :version => gem_version, :errors => errors)
      raise InvalidArgument.new("Invalid gem: #{gem_name}")
    end

    path = ::Gem::RemoteFetcher.fetcher.download(spec, source_uri)
    return path
  end # def download

  def load_package_info(gem_path)
    file = File.new(gem_path, 'r')

    # Set defaults
    if !attributes.include?(:package_name_prefix)
      attributes[:package_name_prefix] = "rubygem"
    end

    ::Gem::Package.open(file, 'r') do |gem|
      spec = gem.metadata

      self.name = [attributes[:package_name_prefix], spec.name].join("-")
      self.license = (spec.license or "no license listed in #{File.basename(file)}")
      self.version = spec.version.to_s
      self.vendor = spec.author
      self.url = spec.homepage
      self.category = "Languages/Development/Ruby"

      # if the gemspec has C extensions defined, then this should be a 'native' arch.
      if !spec.extensions.empty?
        self.architecture = "native"
      else
        self.architecture = "all"
      end

      # make sure we have a description
      description_options = [ spec.description, spec.summary, "#{spec.name} - no description given" ]
      self.description = description_options.find { |d| !(d.nil? or d.strip.empty?) }

      # Upstream rpms seem to do this, might as well share.
      self.provides << "rubygem(#{self.name})"

      # By default, we'll usually automatically provide this, but in the case that we are
      # composing multiple packages, it's best to explicitly include it in the provides list.
      self.provides << "rubygem-#{self.name}"

      spec.runtime_dependencies.map do |dep|
        # rubygems 1.3.5 doesn't have 'Gem::Dependency#requirement'
        if dep.respond_to?(:requirement)
          reqs = dep.requirement.to_s
        else
          reqs = dep.version_requirements
        end

        # Some reqs can be ">= a, < b" versions, let's handle that.
        reqs.to_s.split(/, */).each do |req|
          self.dependencies << "#{attributes[:package_name_prefix]}-#{dep.name} #{req}"
        end
      end # runtime_dependencies
    end # ::Gem::Package
  end # def load_package_info

  def install_to_staging(gem_path)
    if attributes.include?(:path_prefix)
      installdir = "#{staging_path}/#{attributes[:path_prefix]}"
    else
      installdir = File.join(staging_path, ::Gem::dir)
    end

    ::FileUtils.mkdir_p(installdir)
    # TODO(sissel): Allow setting gem tool path
    args = ["gem", "install", "--quiet", "--no-ri", "--no-rdoc",
       "--install-dir", installdir, "--ignore-dependencies", "-E"]
    #if self[:settings][:bin_path]
      #tmp_bin_path = File.join(tmpdir, self[:settings][:bin_path])
      #args += ["--bindir", tmp_bin_path]
      #FileUtils.mkdir_p(tmp_bin_path) # Fixes #27
    #end

    args << gem_path
    safesystem(*args)
  end # def install_to_staging

  public(:input, :output)
end # class FPM::Source::Gem
