require "fpm/namespace"

module FPM::Util
  def safesystem(*args)
    program = args[0]
    # TODO(sissel): Search PATH for program, abort if we can't find it

    success = system(*args)
    if !success
      raise "#{args.first} failed with exit code #{$?.exitstatus}. Full command was: #{args.inspect}"
    end
    return success
  end # def safesystem

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
