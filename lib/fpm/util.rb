def safesystem(*args)
  success = system(*args)
  if !success
    raise "'system(#{args.inspect})' failed with error code: #{$?.exitstatus}"
  end
  return success
end # def safesystem
