def safesystem(*call)
  return_val = system(*call)
  if !return_val
    raise "'#{call}' failed with error code: #{$?.exitstatus}"
  end
  return return_val
end # def safesystem
