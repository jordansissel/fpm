require "fpm/namespace"
require "fileutils"

# Some utility functions
module FPM::Util

  # Raised if safesystem cannot find the program to run.
  class ExecutableNotFound < StandardError; end

  # Raised if a safesystem program exits nonzero
  class ProcessFailed < StandardError; end

  # Raised when a named pipe cannot be copied due to missing functions in fpm and ruby.
  class NamedPipeCannotBeCopied < StandardError; end

  # Raised when an attempting to copy a special file such as a block device.
  class UnsupportedSpecialFile < StandardError; end

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
    stdin_r, stdin_w = IO.pipe

    pid = Process.spawn(env, *args2, :out => stdout_w, :err => stderr_w, :in => stdin_r)

    stdout_w.close; stderr_w.close
    logger.debug("Process is running", :pid => pid)
    if block_given?
      args3 = []
      args3.push(process)           if opts[:process]
      args3.push(stdin_w)           if opts[:stdin]
      args3.push(stdout_r)          if opts[:stdout]
      args3.push(stderr_r)          if opts[:stderr]

      yield(*args3)

      stdin_w.close                 if opts[:stdin] and not stdin_w.closed?
      stdout_r.close                unless stdout_r.closed?
      stderr_r.close                unless stderr_r.closed?
    else
      # If no block given (not interactive) we should close stdin_w because we
      # won't be able to give input which may cause a hang.
      stdin_w.close
      # Log both stdout and stderr as 'info' because nobody uses stderr for
      # actually reporting errors and as a result 'stderr' is a misnomer.
      logger.pipe(stdout_r => :info, stderr_r => :info)
    end

    Process.waitpid(pid)
    status = $?

    return status.exitstatus
  end # def execmd

  # Run a command safely in a way that gets reports useful errors.
  def safesystem(*args)
    # ChildProcess isn't smart enough to run a $SHELL if there's
    # spaces in the first arg and there's only 1 arg.
    if args.size == 1
      args = [ default_shell, "-c", args[0] ]
    end

    if args[0].kind_of?(Hash)
      env = args.shift()
      exit_code = execmd(env, args)
    else
      exit_code = execmd(args)
    end
    program = args[0]
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

  # Get an array containing the recommended 'ar' command for this platform
  # and the recommended options to quickly create/append to an archive
  # without timestamps or uids (if possible).
  def ar_cmd
    return @@ar_cmd if defined? @@ar_cmd

    @@ar_cmd_deterministic = false

    # FIXME: don't assume current directory writeable
    FileUtils.touch(["fpm-dummy.tmp"])
    ["ar", "gar"].each do |ar|
      ["-qc", "-qcD"].each do |ar_create_opts|
        FileUtils.rm_f(["fpm-dummy.ar.tmp"])
        # Return this combination if it creates archives without uids or timestamps.
        # Exitstatus will be nonzero if the archive can't be created,
        # or its table of contents doesn't match the regular expression.
        # Be extra-careful about locale and timezone when matching output.
        system("#{ar} #{ar_create_opts} fpm-dummy.ar.tmp fpm-dummy.tmp 2>/dev/null && env TZ=UTC LANG=C LC_TIME=C #{ar} -tv fpm-dummy.ar.tmp | grep '0/0.*1970' > /dev/null 2>&1")
        if $?.exitstatus == 0
           @@ar_cmd = [ar, ar_create_opts]
           @@ar_cmd_deterministic = true
           return @@ar_cmd
        end
      end
    end
    # If no combination of ar and options omits timestamps, fall back to default.
    @@ar_cmd = ["ar", "-qc"]
    return @@ar_cmd
  ensure
    # Clean up
    FileUtils.rm_f(["fpm-dummy.ar.tmp", "fpm-dummy.tmp"])
  end # def ar_cmd

  # Return whether the command returned by ar_cmd can create deterministic archives
  def ar_cmd_deterministic?
    ar_cmd if not defined? @@ar_cmd_deterministic
    return @@ar_cmd_deterministic
  end

  # Get the recommended 'tar' command for this platform.
  def tar_cmd
    return @@tar_cmd if defined? @@tar_cmd

    # FIXME: don't assume current directory writeable
    FileUtils.touch(["fpm-dummy.tmp"])

    # Prefer tar that supports more of the features we want, stop if we find tar of our dreams
    best="tar"
    bestscore=0
    @@tar_cmd_deterministic = false
    # GNU Tar, if not the default, is usually on the path as gtar, but
    # Mac OS X 10.8 and earlier shipped it as /usr/bin/gnutar
    ["tar", "gtar", "gnutar"].each do |tar|
      opts=[]
      score=0
      ["--sort=name", "--mtime=@0"].each do |opt|
        system("#{tar} #{opt} -cf fpm-dummy.tar.tmp fpm-dummy.tmp > /dev/null 2>&1")
        if $?.exitstatus == 0
          opts << opt
          score += 1
        end
      end
      if score > bestscore
        best=tar
        bestscore=score
        if score == 2
          @@tar_cmd_deterministic = true
          break
        end
      end
    end
    @@tar_cmd = best
    return @@tar_cmd
  ensure
    # Clean up
    FileUtils.rm_f(["fpm-dummy.tar.tmp", "fpm-dummy.tmp"])
  end # def tar_cmd

  # Return whether the command returned by tar_cmd can create deterministic archives
  def tar_cmd_supports_sort_names_and_set_mtime?
    tar_cmd if not defined? @@tar_cmd_deterministic
    return @@tar_cmd_deterministic
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
    when 'fifo'
      if File.respond_to?(:mkfifo)
        File.mkfifo(dst)
      elsif program_exists?("mkfifo")
        safesystem("mkfifo", dst)
      else
        raise NamedPipeCannotBeCopied("Unable to copy. Cannot find program 'mkfifo' and Ruby is missing the 'File.mkfifo' method: #{src}")
      end
    when 'socket'
      require "socket"
      # In 2019, Ruby's FileUtils added this as a way to "copy" a unix socket.
      # Reference: https://github.com/ruby/fileutils/pull/36/files
      UNIXServer.new(dst).close()
    when 'characterSpecial', 'blockSpecial'
      raise  UnsupportedSpecialFile.new("File is device which fpm doesn't know how to copy (#{File.ftype(src)}): #{src}")
    when 'directory'
      FileUtils.mkdir(dst) unless File.exist? dst
    else
      # if the file with the same dev and inode has been copied already -
      # hard link it's copy to `dst`, otherwise make an actual copy
      st = File.lstat(src)
      known_entry = copied_entries[[st.dev, st.ino]]
      if known_entry
        FileUtils.ln(known_entry, dst)
      else
        FileUtils.copy_entry(src, dst, preserve, false,
                             remove_destination)
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

  def erbnew(template_code)
    # In Ruby 2.6(?), Ruby changed how ERB::new is invoked.
    # First, it added keyword args like `ERB.new(..., trim_mode: "-")`
    # Later, it deprecated then removed the safe_level feature.
    # As of Ruby 3.1, warnings are printed at runtime when ERB.new is called with the old syntax.
    # Ruby 2.5 and older does not support the ERB.new keyword args.
    #
    # My tests showed:
    # * Ruby 2.3.0 through 3.0 work correctly with the old syntax.
    # * Ruby 3.1.0 and newer (at time of writing, Ruby 3.2) require the new syntax
    # Therefore, in order to support the most versions of ruby, we need to do a version check
    # to invoke ERB.new correctly and without printed warnings.
    # References: https://github.com/jordansissel/fpm/issues/1894
    # Honestly, I'm not sure if Gem::Version is correct to use in this situation, but it works.

    # on older versions of Ruby, RUBY_VERSION is a frozen string, and
    # Gem::Version.new calls String#strip! which throws an exception.
    # so we have to call String#dup to get an unfrozen copy.
    if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("3.1.0")
      # Ruby 3.0.x and older
      return ERB.new(template_code, nil, "-")
    else
      # Ruby 3.1.0 and newer
      return ERB.new(template_code, trim_mode: "-")
    end
  end
end # module FPM::Util

require 'fpm/util/tar_writer'
