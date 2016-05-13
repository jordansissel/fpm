require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

require "pleaserun/cli"

# A pleaserun package.
#
# This does not currently support 'output'
class FPM::Package::PleaseRun < FPM::Package
  # Copy flags from the PleaseRun::CLI
  ::PleaseRun::CLI.declared_options.each do |o|
    # Skip exposing 'install prefix' flag since only internally we need to use this.
    next if ["--install", "--install-prefix"].include?(o.long_switch)

    option o.long_switch.gsub("[no-]", ""), o.type, o.description, {
      :required => o.required?,
      :multivalued => o.multivalued?,
      :default => o.default_value,
      :environment_variable => o.environment_variable,
      :hidden => o.hidden?
    }.reject { |k,v| v.nil? }
  end

  private
  def input(command)
    flags = ::PleaseRun::CLI.declared_options.collect do |o|
      name = "pleaserun_#{o.attribute_name}".to_sym
      value = attributes[name]
      next if value.nil?

      case o.type
      when :flag
        o.long_switch
      else
        [o.long_switch, value]
      end
    end.reject(&:nil?).flatten


    flags += [ "--install-prefix", staging_path ]
    pleaserun = ::PleaseRun::CLI.new("fpm -s pleaserun")

    # hack to override the logging setup in pleaserun
    l = logger
    pleaserun.define_singleton_method(:setup_logger) do
      instance_variable_set(:@logger, l)
    end
    
    pleaserun.run(flags + command)

    staging_path("install_actions.sh").tap do |install_actions|
      if File.exist?(install_actions)
        scripts[:after_install] = File.read(install_actions)
        File.unlink(install_actions)
      end
    end
  end # def input

  public(:input)
end # class FPM::Package::PleaseRun
