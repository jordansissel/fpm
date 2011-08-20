require "fpm/namespace"
require "fpm/source"
require "rubygems/package"
require "rubygems"
require "fileutils"

class FPM::Source::Gem < FPM::Source
  def self.flags(opts, settings)
    opts.on("--bin-path DIRECTORY",
            "The directory to install gem executables") do |path|
      settings.source[:bin_path] = path
    end
  end # def flags

  def get_source(params)
    gem = @paths.first
    looks_like_name_re = /^[A-Za-z0-9_-]+$/
    if !File.exists?(gem)
      if gem =~ looks_like_name_re
        download(gem, params[:version])
      else
        raise "Path '#{gem}' is not a file and does not appear to be the name of a rubygem."
      end
    end
  end # def get_source

  def can_recurse_dependencies
    true
  end

  def download(gem_name, version=nil)
    # This code mostly mutated from rubygem's fetch_command.rb
    # Code use permissible by rubygems's "GPL or these conditions below"
    # http://rubygems.rubyforge.org/rubygems-update/LICENSE_txt.html

    puts "Trying to download #{gem_name} (version=#{version || 'latest'})"
    dep = ::Gem::Dependency.new gem_name, version
    # How to handle prerelease? Some extra magic options?
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
      raise "Invalid gem? Name: #{gem_name}, Version: #{version}, Errors: #{errors}"
    end

    path = ::Gem::RemoteFetcher.fetcher.download spec, source_uri
    FileUtils.mv path, spec.file_name
    @paths = [spec.file_name]
  end

  def get_metadata
    File.open(@paths.first, 'r') do |f|
      ::Gem::Package.open(f, 'r') do |gem|
        spec = gem.metadata
        %w(
          description
          license
          summary
          version
        ).each do |field|
          self[field.to_sym] = spec.send(field) rescue "unknown"
        end

        self[:name] = "rubygem#{self[:suffix]}-#{spec.name}"
        self[:maintainer] = spec.author
        self[:url] = spec.homepage

        # TODO [Jay]: this will be different for different
        # package managers.  Need to decide how to handle this.
        self[:category] = 'Languages/Development/Ruby'

        # if the gemspec has extensions defined, then this should be a 'native' arch.
        if !spec.extensions.empty?
          self[:architecture] = "native"
        else
          self[:architecture] = "all"
        end

        # make sure we have a description
        descriptions = [ self[:description], self[:summary], "#{spec.name} - no description given" ]
        self[:description] = descriptions.detect { |d| !(d.nil? or d.strip.empty?) }

        self[:dependencies] = []
        spec.runtime_dependencies.map do |dep|
          # rubygems 1.3.5 doesn't have 'Gem::Dependency#requirement'
          if dep.respond_to?(:requirement)
            reqs = dep.requirement.to_s.gsub(/,/, '')
          else
            reqs = dep.version_requirements
          end

          # Some reqs can be ">= a, < b" versions, let's handle that.
          reqs.to_s.split(/, */).each do |req|
            self[:dependencies] << "rubygem#{self[:suffix]}-#{dep.name} #{req}"
          end
        end # runtime_dependencies
      end # ::Gem::Package
    end # File.open (the gem)
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    gem = @paths.first
    if self[:prefix]
      installdir = "#{tmpdir}/#{self[:prefix]}"
      # TODO(sissel): Overwriting @paths is bad mojo and confusing...
      # Maybe we shouldn't?
      @paths = [ self[:prefix] ]
    else
      installdir = File.join(tmpdir, ::Gem::dir)
      @paths = [ ::Gem::dir ]
    end

    ::FileUtils.mkdir_p(installdir)
    args = ["gem", "install", "--quiet", "--no-ri", "--no-rdoc",
       "--install-dir", installdir, "--ignore-dependencies", "-E"]
    if self[:settings][:bin_path]
      tmp_bin_path = File.join(tmpdir, self[:settings][:bin_path])
      args += ["--bindir", tmp_bin_path]
      @paths << self[:settings][:bin_path]
      FileUtils.mkdir_p(tmp_bin_path) # Fixes #27
    end

    args << gem
    system(*args)

    # make paths relative  (/foo becomes ./foo)
    tar(tar_path, @paths.collect {|p| ".#{p}"}, tmpdir)
    FileUtils.rm_r(tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
