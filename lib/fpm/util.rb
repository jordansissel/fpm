require "fpm/namespace"
require "childprocess"

# Some utility functions
module FPM::Util
  # Raised if safesystem cannot find the program to run.
  class ExecutableNotFound < StandardError; end

  # Raised if a safesystem program exits nonzero
  class ProcessFailed < StandardError; end

  # Is the given program in the system's PATH?
  def program_in_path?(program)
    # Scan path to find the executable
    # Do this to help the user get a better error message.
    envpath = ENV["PATH"].split(":")
    return envpath.select { |p| File.executable?(File.join(p, program)) }.any?
  end # def program_in_path

  # Run a command safely in a way that gets reports useful errors.
  def safesystem(*args)
    # ChildProcess isn't smart enough to run a $SHELL if there's
    # spaces in the first arg and there's only 1 arg.
    if args.size == 1
      args = [ ENV["SHELL"], "-c", args[0] ]
    end
    program = args[0]

    # Scan path to find the executable
    # Do this to help the user get a better error message.
    if !program.include?("/") and !program_in_path?(program)
      raise ExecutableNotFound.new(program)
    end

    @logger.debug("Running command", :args => args)

    # Create a pair of pipes to connect the
    # invoked process to the cabin logger
    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    process           = ChildProcess.build(*args)
    process.io.stdout = stdout_w
    process.io.stderr = stderr_w

    process.start
    stdout_w.close; stderr_w.close
    @logger.debug('Process is running', :pid => process.pid)
    @logger.pipe(stdout_r => :info, stderr_r => :error)

    process.wait
    success = (process.exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{process.exit_code})" \
                              ". Full command was:#{args.inspect}")
    end
    return success
  end # def safesystem

# Run a command safely in a way that captures output and status.
  def safesystemout(*args)
    if args.size == 1
      args = [ ENV["SHELL"], "-c", args[0] ]
    end
    program = args[0]

    if !program.include?("/") and !program_in_path?(program)
      raise ExecutableNotFound.new(program)
    end

    @logger.debug("Running command", :args => args)

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    process           = ChildProcess.build(*args)
    process.io.stdout = stdout_w
    process.io.stderr = stderr_w

    process.start
    stdout_w.close; stderr_w.close
    stdout_r_str = stdout_r.read
    stdout_r.close; stderr_r.close
    @logger.debug("Process is running", :pid => process.pid)

    process.wait
    success = (process.exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{process.exit_code})" \
                              ". Full command was:#{args.inspect}")
    end

    return stdout_r_str
  end # def safesystemout

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

  # Run a block with a value.
  # Useful in lieu of assigning variables 
  def with(value, &block)
    block.call(value)
  end # def with
end # module FPM::Util
