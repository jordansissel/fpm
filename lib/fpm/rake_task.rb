require "fpm/namespace"
require "rake"
require "rake/tasklib"

class FPM::RakeTask < Rake::TaskLib
  class Options
    attr_accessor :args

    def initialize(defaults=nil)
      if defaults.nil?
        @h = Hash.new
      else
        @h = defaults
      end
    end

    def method_missing(m, *args)
      if m.end_with?("=")
        raise ArgumentError, "#{self.class.name}##{m} ... Expected 1 arg, got #{args.length}" if args.length != 1
        @h[m[0...-1]] = args[0]
      else
        raise ArgumentError, "Expected 0 arg, got #{args.length}" if args.length != 0
        return @h[m]
      end
    end

    def to_h
      return @h
    end
  end # Options

  attr_reader :options

  def initialize(package_name, opts = {}, &block)
    #@options = OpenStruct.new(:name => package_name.to_s)
    @options = Options.new(:name => package_name.to_s)
    @source, @target = opts.values_at(:source, :target).map(&:to_s)
    @directory = File.expand_path(opts[:directory].to_s)

    (@source.empty? || @target.empty? || options.name.empty?) &&
      abort("Must specify package name, source and output")

    desc "Package #{@name}" unless ::Rake.application.last_description

    task(options.name) do |_, task_args|
      block.call(*[options, task_args].first(block.arity)) if block_given?
      abort("Must specify args") if options.args.nil?
      @args = options.args
      run_cli
    end
  end

  private

  def parsed_options
    options.to_h.map do |option, value|
      opt = option.to_s.tr("_", "-")

      case
      when value.is_a?(String), value.is_a?(Symbol)
        %W(--#{opt} #{value})
      when value.is_a?(Array)
        value.map { |v| %W(--#{opt} #{v}) }
      when value.is_a?(TrueClass)
        "--#{opt}"
      when value.is_a?(FalseClass)
        "--no-#{opt}"
      else
        fail TypeError, "Unexpected type: #{value.class}"
      end
    end
  end

  def run_cli
    require "fpm"
    require "fpm/command"

    args = %W(-t #{@target} -s #{@source} -C #{@directory})
    args << parsed_options
    args << @args

    args.flatten!.compact!

    abort 'FPM failed!' unless FPM::Command.new("fpm").run(args) == 0
  end
end
