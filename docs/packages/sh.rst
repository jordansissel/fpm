sh - Self-managing shell archive
================================

The 'sh' output in fpm will generate a shell script that is, itself, an archive.

The resulting shell script will install the files you provided. You can run the
resulting shell script to see more helpful information.

  # Create an example.sh package
  % fpm -s empty -t sh -n example

  # Get help.
  % ./example.sh -h


Supported Uses in FPM
---------------------

fpm supports using ``sh`` only as an output type. This means you can create ``sh`` packages from input types like ``deb``, ``dir``, or ``npm``

sh-specific command line flags
-------------------------------

.. include:: cli/sh.rst
