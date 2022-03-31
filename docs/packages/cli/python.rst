* ``--[no-]python-dependencies``
    - Include requirements defined in setup.py as dependencies.
* ``--[no-]python-downcase-dependencies``
    - Should the package dependencies be in lowercase?
* ``--[no-]python-downcase-name``
    - Should the target package name be in lowercase?
* ``--[no-]python-fix-dependencies``
    - Should the package dependencies be prefixed?
* ``--[no-]python-fix-name``
    - Should the target package name be prefixed?
* ``--[no-]python-internal-pip``
    - Use the pip module within python to install modules - aka 'python -m pip'. This is the recommended usage since Python 3.4 (2014) instead of invoking the 'pip' script
* ``--[no-]python-obey-requirements-txt``
    - Use a requirements.txt file in the top-level directory of the python package for dependency detection.
* ``--python-bin PYTHON_EXECUTABLE``
    - The path to the python executable you wish to run.
* ``--python-disable-dependency python_package_name``
    - The python package name to remove from dependency list
* ``--python-easyinstall EASYINSTALL_EXECUTABLE``
    - The path to the easy_install executable tool
* ``--python-install-bin BIN_PATH``
    - The path to where python scripts should be installed to.
* ``--python-install-data DATA_PATH``
    - The path to where data should be installed to. This is equivalent to 'python setup.py --install-data DATA_PATH
* ``--python-install-lib LIB_PATH``
    - The path to where python libs should be installed to (default depends on your python installation). Want to find out what your target platform is using? Run this: python -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()'
* ``--python-package-name-prefix PREFIX``
    - Name to prefix the package name with.
* ``--python-package-prefix NAMEPREFIX``
    - (DEPRECATED, use --package-name-prefix) Name to prefix the package name with.
* ``--python-pip PIP_EXECUTABLE``
    - The path to the pip executable tool. If not specified, easy_install is used instead
* ``--python-pypi PYPI_URL``
    - PyPi Server uri for retrieving packages.
* ``--python-scripts-executable PYTHON_EXECUTABLE``
    - Set custom python interpreter in installing scripts. By default distutils will replace python interpreter in installing scripts (specified by shebang) with current python interpreter (sys.executable). This option is equivalent to appending 'build_scripts --executable PYTHON_EXECUTABLE' arguments to 'setup.py install' command.
* ``--python-setup-py-arguments setup_py_argument``
    - Arbitrary argument(s) to be passed to setup.py
* ``--python-trusted-host PYPI_TRUSTED``
    - Mark this host or host:port pair as trusted for pip

