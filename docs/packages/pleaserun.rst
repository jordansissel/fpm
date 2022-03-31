pleaserun - Pleaserun services
==============================

Pleaserun helps generate service definitions for a variety of service manangers
such as systemd and sysv.

When used as an input, fpm will generate a package that include multiple service
definitions, one for each type (systemd, sysv, etc). At package installation, the package
will attempt to detect the best service manager used on the system and will
install only that definition.

You can learn more on the project website: https://github.com/jordansissel/pleaserun#readme

Supported Uses in FPM
---------------------

fpm supports using ``pleaserun`` only as an input type. This means you can convert
``pleaserun`` input packages to output packages like ``deb``, ``rpm``, and more.

pleaserun-specific command line flags
-------------------------------

.. include:: cli/pleaserun.rst
