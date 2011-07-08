require "fpm/namespace"

class FPM::Flags
  def initialize(opts, flag_prefix, help_prefix)
    @opts = opts
    @flag_prefix = flag_prefix
    @help_prefix = help_prefix
  end # def initialize

  def on(*args, &block)
    fixed_args = args.collect do |arg|
      if arg =~ /^--/
        "--#{@flag_prefix}-#{arg.gsub(/^--/, "")}"
      else
        "(#{@help_prefix}) #{arg}"
      end
    end
    @opts.on(*fixed_args, &block)
  end # def on
end # class FPM::Flags
