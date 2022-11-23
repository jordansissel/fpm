require "fpm/package"
require "fpm/recipe"

# This class is the parent of all source based packages.
# If you want to implement a source based FPM package type, you'll inherit from
# this.
class FPM::SourcePackage < FPM::Package
  attr_reader :recipe

  def initialize(recipe_file)
    super()
    @recipe = FPM::Recipe.new(recipe_file)
  end

  def download_source(url, dir)
    safesystem("wget", "-P", dir, url)
  end

  class << self
    def inherited(klass)
      @subclasses ||= {}
      @subclasses[klass.name.gsub(/.*:/, "").downcase] = klass
    end

    def types
      return @subclasses
    end
  end
end
