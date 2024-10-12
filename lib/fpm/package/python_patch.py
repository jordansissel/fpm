import pkg_resources
import re
import sys
from setuptools.dist import Distribution


def gen_safe_name(allow_underscores):
    if allow_underscores:
        regex = '[^A-Za-z0-9_.]+'
    else:
        # This matches the original verion in pkg_resources.
        regex = '[^A-Za-z0-9.]+'

    def safe_name(name):
        return re.sub(regex, '-', name)

    return safe_name


# Use simple argument parsing--older python lacks argparse and optparse has no
# good way to ignore unrecognized options (which need to be passed through).
pkg_resources.safe_name = gen_safe_name('--allow-underscores' in sys.argv)


try:
    # Many older modules include a setup.py that uses distutils.core, which
    # does not support the install_requires attribute. Monkey-patch
    # distutils.core in case it is used.
    import distutils.core

    fpm_orig_setup = distutils.core.setup

    def setup(**attrs):
        attrs['distclass'] = Distribution
        fpm_orig_setup(**attrs)

    distutils.core.setup = setup

except ImportError:
    # distutils is slated to be deprecated in python 3.10 (PEP 632). If
    # distutils.core fails to import, then assume setuptools is to be used
    # anyway, hence nothing needs to be done.
    pass

# This needs a setup.py in the current dir; fpm does a chdir() to the unpacked
# module.
setup_file = 'setup.py'
with open(setup_file) as f:
    setup_contents = f.read()
    # Older versions of python require the contents to end with a newline.
    if setup_contents[-1] != "\n":
        setup_contents += "\n"
    setup_code = compile(setup_contents, setup_file, 'exec')

# We need to use exec() rather than import in order to run the target code
# within the same scope. Otherwise, code which runs only under '__main__' would
# not run.
exec(setup_code, dict(globals(), __file__=setup_file))
