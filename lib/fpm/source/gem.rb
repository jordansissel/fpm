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
    
    specs_and_sources, errors =
      ::Gem::SpecFetcher.fetcher.fetch_with_errors(dep, false, true, false)
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
          self[field] = spec.send(field)
        end

        self[:name] = "rubygem-#{spec.name}"
        self[:maintainer] = spec.author
        self[:url] = spec.homepage

        # TODO [Jay]: this will be different for different
        # package managers.  Need to decide how to handle this.
        self[:category] = 'Languages/Development/Ruby'

        self[:dependencies] = spec.runtime_dependencies.map do |dep|
          reqs = dep.requirement.to_s.gsub(/,/, '')
          "rubygem-#{dep.name} #{reqs}"
        end
      end # ::Gem::Package
    end # File.open (the gem)
  end # def get_metadata

  def make_tarball!(tar_path)
    tmpdir = "#{tar_path}.dir"
    installdir = "#{tmpdir}/#{::Gem::dir}"
    ::FileUtils.mkdir_p(installdir)
    args = ["gem", "install", "--quiet", "--no-ri", "--no-rdoc",
       "--install-dir", installdir, "--ignore-dependencies", @paths.first]
    system(*args)
    tar(tar_path, ".", tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
