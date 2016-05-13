# The following python code helps predicting easy_install's default behavior.
# See: http://stackoverflow.com/a/9155056
from setuptools.command.easy_install import easy_install
class _easy_install_default(easy_install):
  """ class easy_install had problems with the fist parameter not being
      an instance of Distribution, even though it was. This is due to
      some import-related mess.
      """

  def __init__(self):
    from distutils.dist import Distribution
    dist = Distribution()
    self.distribution = dist
    self.initialize_options()
    self._dry_run = None
    self.verbose = dist.verbose
    self.force = None
    self.help = 0
    self.finalized = 0

default_options = _easy_install_default()
import distutils.errors
try:
  default_options.finalize_options()
except distutils.errors.DistutilsError:
  pass

__all__=[default_options]
