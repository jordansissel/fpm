require 'fpm/namespace'

require 'rubygems/package'

class FPM::Gem < FPM::Source

  def get_metadata
    File.open(@path, 'r') do |f|
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
          reqs = dep.requirements.gsub(/,/, '')
          "rubygem-#{dep.name} #{reqs}"
        end
      end
    end
  end
end
