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
    license
    vendor
  ).each do |attr|
    attr = :"#{attr}"
    define_method(attr) { self[attr] }
    define_method(:"#{attr}=") { |v| self[attr] = v}
  end

  def initialize
    @logger = Logger.new(STDERR)
    @logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN
  end # def initialize

  # Add a new argument to this source
  # The effect of this is specific to the source's implementation,
  # but in general this means you are adding something to this source.
  def <<(arg)
    raise NotImplementedError.new
  end # def <<

end # class FPM::Source
