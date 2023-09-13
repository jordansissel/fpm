solaris - Solaris SRV4 package format
=====================================

This package format is typically used in older Solaris versions (Solaris 7, 8,
9, and 10). You may also know them by files with a SUNW prefix and may have file names that end in ".pkg".

If you're using Solaris 11, OpenSolaris, or Illumos, you might want to use `the newer package format, p5p`_. 

.. _newer package format, p5p: /packages/p5p.html

Supported Uses in FPM
---------------------

fpm supports using ``solaris`` only as an output type. This means you can create ``solaris`` packages from input types like ``deb``, ``dir``, or ``npm``

solaris-specific command line flags
-----------------------------------

.. include:: cli/solaris.rst
