* ``--virtualenv-find-links PIP_FIND_LINKS``
    - If a url or path to an html file, then parse for links to archives. If a local path or file:// url that's a directory, then look for archives in the directory listing.
* ``--[no-]virtualenv-fix-name``
    - Should the target package name be prefixed?
* ``--virtualenv-install-location DIRECTORY``
    - DEPRECATED: Use --prefix instead.  Location to which to install the virtualenv by default.
* ``--virtualenv-other-files-dir DIRECTORY``
    - Optionally, the contents of the specified directory may be added to the package. This is useful if the virtualenv needs configuration files, etc.
* ``--virtualenv-package-name-prefix PREFIX``
    - Name to prefix the package name with.
* ``--virtualenv-pypi PYPI_URL``
    - PyPi Server uri for retrieving packages.
* ``--virtualenv-pypi-extra-url PYPI_EXTRA_URL``
    - PyPi extra-index-url for pointing to your priviate PyPi
* ``--[no-]virtualenv-setup-install``
    - After building virtualenv run setup.py install useful when building a virtualenv for packages and including their requirements from 
* ``--[no-]virtualenv-system-site-packages``
    - Give the virtual environment access to the global site-packages

