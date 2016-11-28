The goal of fpm is to make it easy and quick to build packages such as rpms,
debs, OSX packages, etc.

fpm, as a project, exists with the following principles in mind:

* If fpm is not helping you make packages easily, then there is a bug in fpm.
* If you are having a bad time with fpm, then there is a bug in fpm.
* If the documentation is confusing, then this is a bug in fpm.

If there is a bug in fpm, then we can work together to fix it. If you wish to
report a bug/problem/whatever, I welcome you to do on `the project issue tracker`_.

.. _the project issue tracker: https://github.com/jordansissel/fpm/issues

You can find out how to use fpm in the `documentation`_.

.. _documentation: https://fpm.readthedocs.io/en/latest/

Backstory
---------

Sometimes packaging is done wrong (because you can't do it right for all
situations), but small tweaks can fix it.

And sometimes, there isn't a package available for the tool you need.

And sometimes if you ask "How do I get python 3 on CentOS 5?" some unhelpful
trolls will tell you to "Use another distro"

Further, a job switches have me flipping between Ubuntu and CentOS. These use
two totally different package systems with completely different packaging
policies and support tools. Learning both was painful and confusing. I want to
save myself (and you) that pain in the future.

It should be easy to say "here's my install dir and here's some dependencies;
please make a package"

The Solution - FPM
------------------

I wanted a simple way to create packages without needing to memorize too much.

I wanted a tool to help me deliver software with minimal steps or training.

The goal of FPM is to be able to easily build platform-native packages.

With fpm, you can do many things, including:

* Creating packages easily (deb, rpm, freebsd, etc)
* Tweaking existing packages (removing files, changing metadata/dependencies)
* Stripping pre/post/maintainer scripts from packages

.. include: docs/installing

Things that should work
-----------------------

Sources:

* gem (even autodownloaded for you)
* python modules (autodownload for you)
* pear (also downloads for you)
* directories
* tar(.gz) archives
* rpm
* deb
* node packages (npm)
* pacman (ArchLinux) packages

Targets:

* deb
* rpm
* solaris
* freebsd
* tar
* directories
* Mac OS X `.pkg` files (`osxpkg`)
* pacman (ArchLinux) packages

.. include: docs/contributing
