module FPM
  DIRS = {
    :templates => File.expand_path(
      File.join(
        File.dirname(__FILE__),
        '..',
        '..',
        'templates'
      )
    )
  }
end
