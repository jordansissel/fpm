require "ostruct"
require "rake"
require "rake/tasklib"

class FPM::RakeTask < Rake::TaskLib
  attr_reader :options

  def initialize(*args, source:, target:, directory: ".", &block)
    @options = OpenStruct.new
    @source = source.to_s
    @target = target.to_s
    @directory = File.expand_path(directory)

    abort("Must specify source and output") if @source.empty? || @target.empty?
    options.name = args.shift.to_s || abort("Must specify a package name")

    desc "Package #{@name}" unless ::Rake.application.last_comment

    task(options.name, *args) do |_, task_args|
      block.call(*[options, task_args].first(block.arity)) if block
      abort("Must specify args") unless (@args = options.delete_field(:args))

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

    exit(FPM::Command.new("fpm").run(args) || 0)
  end
end
