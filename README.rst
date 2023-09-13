fpm
===

|Chat| |Gem|

The goal of fpm is to make it easy and quick to build packages such as rpms,
debs, OSX packages, etc.

fpm, as a project, exists to help you build packages, therefore:

* If fpm is not helping you make packages easily, then there is a bug in fpm.
* If you are having a bad time with fpm, then there is a bug in fpm.
* If the documentation is confusing, then this is a bug in fpm.

If there is a bug in fpm, then we can work together to fix it. If you wish to
report a bug/problem/whatever, I welcome you to do on `the project issue tracker`_.

.. _the project issue tracker: https://github.com/jordansissel/fpm/issues

You can find out how to use fpm in the `documentation`_.

.. _documentation: https://fpm.readthedocs.io/en/latest/

You can learn how to install fpm on your platform in the `installation guide`_.

.. _installation guide: https://fpm.readthedocs.io/en/latest/installation.html

Project Principles
------------------

* Community: If a newbie has a bad time, it's a bug.
* Engineering: Make it work, then make it right, then make it fast.
* Capabilities: If it doesn't do a thing today, we can make it do it tomorrow.


Backstory
---------

Sometimes packaging is done wrong (because you can't do it right for all
situations), but small tweaks can fix it.

And sometimes, there isn't a package available for the tool you need.

And sometimes if you ask "How do I get python 3.9 on RHEL 8?" some unhelpful
trolls will tell you to "Use another distro"

Further, job switches have me flipping between Ubuntu and CentOS. These use
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

.. |Chat| image:: https://img.shields.io/badge/irc-%23fpm%20on%20freenode-brightgreen.svg
   :target: https://webchat.freenode.net/?channels=fpm
.. |Gem| image:: https://img.shields.io/gem/v/fpm.svg
   :target: https://rubygems.org/gems/fpm
