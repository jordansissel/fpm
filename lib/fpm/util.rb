require "fpm/namespace"

# Some utility functions
module FPM::Util
  # Raised if safesystem cannot find the program to run.
  class ExecutableNotFound < StandardError; end

  # Raised if a safesystem program exits nonzero
  class ProcessFailed < StandardError; end

  # Run a command safely in a way that gets reports useful errors.
  def safesystem(*args)
    program = args[0]

    # Scan path to find the executable
    # Do this to help the user get a better error message.
    if !program.include("/")
      envpath = ENV["PATH"].split(":")
      if envpath.select { |p| File.executable?(File.join(p, program)) }.empty?
        raise ExecutableNotFound.new(program)
      end
    end

    success = system(*args)
    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{$?.exitstatus})" \
                              ". Full command was:#{args.inspect}")
    end
    return success
  end # def safesystem

  # Get the recommended 'tar' command for this platform.
  def tar_cmd
    # Rely on gnu tar for solaris and OSX.
    case %x{uname -s}.chomp
    when "SunOS"
      return "gtar"
    when "Darwin"
      return "gnutar"
    else
      return "tar"
    end
  end # def tar_cmd
end # module FPM::Util
