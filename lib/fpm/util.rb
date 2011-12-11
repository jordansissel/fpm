def safesystem(*args)
  success = system(*args)
  if !success
    raise "'system(#{args.inspect})' failed with error code: #{$?.exitstatus}"
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