module FPM
  module Target; end # TODO(sissel): Make this the 'package' ?
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
