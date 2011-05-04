require "fpm/namespace"
require "fpm/source"
require "rubygems/package"
require "rubygems"
require "fileutils"

class FPM::Source::Gem < FPM::Source
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

    puts "Trying to download #{gem_name} (version=#{version})"
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

        self[:executables] = spec.executables

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
      @paths = [ self[:prefix] ]
    else
      installdir = "#{tmpdir}/#{::Gem::dir}"
      @paths = [ ::Gem::dir ]
    end
    ::FileUtils.mkdir_p(installdir)
    args = ["gem", "install", "--quiet", "--no-ri", "--no-rdoc",
       "--install-dir", installdir, "--ignore-dependencies", gem]
    system(*args)

    if not self[:executables].empty? and self[:gembinpath]
      gembinpath = "#{tmpdir}/#{self[:gembinpath]}"
      FileUtils.mkdir_p(gembinpath)
      self[:executables].each do |ex|
        FileUtils.cp("#{installdir}/bin/#{ex}", gembinpath)
        @paths << "#{self[:gembinpath]}/#{ex}"
      end
    end

    tar(tar_path, @paths.map { |p| ".#{p}" }, tmpdir)
    FileUtils.rm_r(tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
