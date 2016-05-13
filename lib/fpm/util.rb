require "fpm/namespace"
require "childprocess"
require "ffi"

# Some utility functions
module FPM::Util
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  # mknod is __xmknod in glibc a wrapper around mknod to handle
  # various stat struct formats. See bits/stat.h in glibc source
  begin
    attach_function :mknod, :mknod, [:string, :uint, :ulong], :int
  rescue FFI::NotFoundError
    # glibc/io/xmknod.c int __xmknod (int vers, const char *path, mode_t mode, dev_t *dev)
    attach_function :xmknod, :__xmknod, [:int, :string, :uint, :pointer], :int
  end

  # Raised if safesystem cannot find the program to run.
  class ExecutableNotFound < StandardError; end

  # Raised if a safesystem program exits nonzero
  class ProcessFailed < StandardError; end

  # Is the given program in the system's PATH?
  def program_in_path?(program)
    # return false if path is not set
    return false unless ENV['PATH']
    # Scan path to find the executable
    # Do this to help the user get a better error message.
    envpath = ENV["PATH"].split(":")
    return envpath.select { |p| File.executable?(File.join(p, program)) }.any?
  end # def program_in_path

  def program_exists?(program)
    # Scan path to find the executable
    # Do this to help the user get a better error message.
    return program_in_path?(program) if !program.include?("/")
    return File.executable?(program)
  end # def program_exists?

  def default_shell
    shell = ENV["SHELL"]
    return "/bin/sh" if shell.nil? || shell.empty?
    return shell
  end

  ############################################################################
  # execmd([env,] cmd [,opts])
  #
  # Execute a command as a child process. The function allows to:
  #
  # - pass environment variables to child process,
  # - communicate with stdin, stdout and stderr of the child process via pipes,
  # - retrieve execution's status code.
  #
  # ---- EXAMPLE 1 (simple execution)
  #
  # if execmd(['which', 'python']) == 0
  #   p "Python is installed"
  # end
  #
  # ---- EXAMPLE 2 (custom environment variables)
  #
  # execmd({:PYTHONPATH=>'/home/me/foo'}, [ 'python', '-m', 'bar'])
  #
  # ---- EXAMPLE 3 (communicating via stdin, stdout and stderr)
  #
  # script = <<PYTHON
  # import sys
  # sys.stdout.write("normal output\n")
  # sys.stdout.write("narning or error\n")
  # PYTHON
  # status = execmd('python') do |stdin,stdout,stderr|
  #   stdin.write(script)
  #   stdin.close
  #   p "STDOUT: #{stdout.read}"
  #   p "STDERR: #{stderr.read}"
  # end
  # p "STATUS: #{status}"
  #
  # ---- EXAMPLE 4 (additional options)
  #
  # execmd(['which', 'python'], :process=>true, :stdin=>false, :stderr=>false) do |process,stdout|
  #  p = stdout.read.chomp
  #  process.wait
  #  if (x = process.exit_code) == 0
  #    p "PYTHON: #{p}"
  #  else
  #    p "ERROR:  #{x}"
  #  end
  # end
  #
  #
  # OPTIONS:
  #
  #   :process (default: false) -- pass process object as the first argument the to block,
  #   :stdin   (default: true)  -- pass stdin object of the child process to the block for writting,
  #   :stdout  (default: true)  -- pass stdout object of the child process to the block for reading,
  #   :stderr  (default: true)  -- pass stderr object of the child process to the block for reading,
  #
  def execmd(*args)
    i = 0
    if i < args.size
      if args[i].kind_of?(Hash)
        # args[0] may contain environment variables
        env = args[i]
        i += 1
      else
        env = Hash[]
      end
    end

    if i < args.size
      if args[i].kind_of?(Array)
        args2 = args[i]
      else
        args2 = [ args[i] ]
      end
      program = args2[0]
      i += 1
    else
      raise ArgumentError.new("missing argument: cmd")
    end

    if i < args.size
      if args[i].kind_of?(Hash)
        opts = Hash[args[i].map {|k,v| [k.to_sym, v]} ]
        i += 1
      end
    else
      opts = Hash[]
    end

    opts[:process] = false unless opts.include?(:process)
    opts[:stdin]   = true  unless opts.include?(:stdin)
    opts[:stdout]  = true  unless opts.include?(:stdout)
    opts[:stderr]  = true  unless opts.include?(:stderr)

    if !program.include?("/") and !program_in_path?(program)
      raise ExecutableNotFound.new(program)
    end

    logger.debug("Running command", :args => args2)

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    process = ChildProcess.build(*args2)
    process.environment.merge!(env)

    process.io.stdout = stdout_w
    process.io.stderr = stderr_w

    if block_given? and opts[:stdin]
      process.duplex = true
    end

    process.start

    stdout_w.close; stderr_w.close
    logger.debug("Process is running", :pid => process.pid)
    if block_given?
      args3 = []
      args3.push(process)           if opts[:process]
      args3.push(process.io.stdin)  if opts[:stdin]
      args3.push(stdout_r)          if opts[:stdout]
      args3.push(stderr_r)          if opts[:stderr]

      yield(*args3)

      process.io.stdin.close        if opts[:stdin] and not process.io.stdin.closed?
      stdout_r.close                unless stdout_r.closed?
      stderr_r.close                unless stderr_r.closed?
    else
      # Log both stdout and stderr as 'info' because nobody uses stderr for
      # actually reporting errors and as a result 'stderr' is a misnomer.
      logger.pipe(stdout_r => :info, stderr_r => :info)
    end

    process.wait if process.alive?

    return process.exit_code
  end # def execmd

  # Run a command safely in a way that gets reports useful errors.
  def safesystem(*args)
    # ChildProcess isn't smart enough to run a $SHELL if there's
    # spaces in the first arg and there's only 1 arg.
    if args.size == 1
      args = [ default_shell, "-c", args[0] ]
    end
    program = args[0]

    exit_code = execmd(args)
    success = (exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{exit_code})" \
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

    stdout_r_str = nil
    exit_code = execmd(args, :stdin=>false, :stderr=>false) do |stdout|
      stdout_r_str = stdout.read
    end
    success = (exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{exit_code})" \
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
      # Try running gnutar, it was renamed(??) in homebrew to 'gtar' at some point, I guess? I don't know.
      ["gnutar", "gtar"].each do |tar|
        system("#{tar} > /dev/null 2> /dev/null")
        return tar unless $?.exitstatus == 127
      end
    when "FreeBSD"
      # use gnutar instead
      return "gtar"
    else
      return "tar"
    end
  end # def tar_cmd

  # wrapper around mknod ffi calls
  def mknod_w(path, mode, dev)
    rc = -1
    case %x{uname -s}.chomp
    when 'Linux'
      # bits/stat.h #define _MKNOD_VER_LINUX  0
      rc = xmknod(0, path, mode, FFI::MemoryPointer.new(dev))
    else
      rc = mknod(path, mode, dev)
    end
    rc
  end

  def copy_metadata(source, destination)
    source_stat = File::lstat(source)
    dest_stat = File::lstat(destination)

    # If this is a hard-link, there's no metadata to copy.
    # If this is a symlink, what it points to hasn't been copied yet.
    return if source_stat.ino == dest_stat.ino || dest_stat.symlink?

    File.utime(source_stat.atime, source_stat.mtime, destination)
    mode = source_stat.mode
    begin
      File.lchown(source_stat.uid, source_stat.gid, destination)
    rescue Errno::EPERM
      # clear setuid/setgid
      mode &= 01777
    end

    unless source_stat.symlink?
      File.chmod(mode, destination)
    end
  end # def copy_metadata


  def copy_entry(src, dst, preserve=false, remove_destination=false)
    case File.ftype(src)
    when 'fifo', 'characterSpecial', 'blockSpecial', 'socket'
      st = File.stat(src)
      rc = mknod_w(dst, st.mode, st.dev)
      raise SystemCallError.new("mknod error", FFI.errno) if rc == -1
    when 'directory'
      FileUtils.mkdir(dst) unless File.exists? dst
    else
      # if the file with the same dev and inode has been copied already -
      # hard link it's copy to `dst`, otherwise make an actual copy
      st = File.lstat(src)
      known_entry = copied_entries[[st.dev, st.ino]]
      if known_entry
        FileUtils.ln(known_entry, dst)
      else
        FileUtils.copy_entry(src, dst, preserve=preserve,
                             remove_destination=remove_destination)
        copied_entries[[st.dev, st.ino]] = dst
      end
    end # else...
  end # def copy_entry

  def copied_entries
    # TODO(sissel): I wonder that this entry-copy knowledge needs to be put
    # into a separate class/module. As is, calling copy_entry the same way
    # in slightly different contexts will result in weird or bad behavior.
    # What I mean is if we do:
    #   pkg = FPM::Package::Dir...
    #   pkg.output()...
    #   pkg.output()...
    # The 2nd output call will fail or behave weirdly because @copied_entries
    # is already populated. even though this is anew round of copying.
    return @copied_entries ||= {}
  end # def copied_entries

  def expand_pessimistic_constraints(constraint)
    name, op, version = constraint.split(/\s+/)

    if op == '~>'

      new_lower_constraint = "#{name} >= #{version}"

      version_components = version.split('.').collect { |v| v.to_i }

      version_prefix = version_components[0..-3].join('.')
      portion_to_work_with = version_components.last(2)

      prefix = ''
      unless version_prefix.empty?
        prefix = version_prefix + '.'
      end

      one_to_increment = portion_to_work_with[0].to_i
      incremented = one_to_increment + 1

      new_version = ''+ incremented.to_s + '.0'

      upper_version = prefix + new_version

      new_upper_constraint = "#{name} < #{upper_version}"

      return [new_lower_constraint,new_upper_constraint]
    else
      return [constraint]
    end
  end #def expand_pesimistic_constraints

  def logger
    @logger ||= Cabin::Channel.get
  end # def logger
end # module FPM::Util

require 'fpm/util/tar_writer'
