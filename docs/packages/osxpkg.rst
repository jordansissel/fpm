osxpkg - Apple macOS and OSX packages
=====================================

Supported Uses in FPM
---------------------

fpm supports input and output for Apple's package files. These files typically
end in ".pkg". This means you can read a ``.pkg`` file and convert it to a different
output type (such as a `dir` or `rpm`). It also means you can create a ``.pkg``
package file.

osxpkg-specific command line flags
-------------------------------

.. include:: cli/osxpkg.rst
