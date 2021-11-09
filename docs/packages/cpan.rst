cpan - Perl packages from CPAN
===============================

Supported Uses in FPM
---------------------

fpm supports using ``cpan`` only as an input type. This means you can convert
``cpan`` input packages to output packages like ``deb``, ``rpm``, and more.

Arguments when used as input type
---------------------------------

Any number of arguments are supported and behave as follows:

* A name to search on MetaCPAN_. If a module is found on MetaCPAN_, it will be downloaded and used when building the package.
* or, a local directory containing a Perl module to build. 

.. _MetaCPAN: https://metacpan.org/

Sample Usage
------------

Let's take the `Regexp::Common <https://metacpan.org/pod/Regexp::Common>`_ Perl module and package it as a deb. We can let fpm do the hard work here of finding the module on cpan and downloading it::

  % fpm -s cpan -t deb Regexp::Common
  Downcasing provides 'perl-Regexp-Common' because deb packages  don't work so good with uppercase names {:level=>:warn}
  Downcasing provides 'perl-Regexp-Common-Entry' because deb packages  don't work so good with uppercase names {:level=>:warn}
  Debian tools (dpkg/apt) don't do well with packages that use capital letters in the name. In some cases it will automatically downcase them, in others it will not. It is confusing. Best to not use any capital letters at all. I have downcased the package name for you just to be safe. {:oldname=>"perl-Regexp-Common", :fixedname=>"perl-regexp-common", :level=>:warn}
  Debian packaging tools generally labels all files in /etc as config files, as mandated by policy, so fpm defaults to this behavior for deb packages. You can disable this default behavior with --deb-no-default-config-files flag {:level=>:warn}
  Created package {:path=>"perl-regexp-common_2017060201_all.deb"}

Fpm did a bunch of nice work for you. First, it searched MetaCPAN_ for Regexp::Common. Then it downloaded the latest version. If you wanted to specify a version, you can use the ``-v`` flag, such as ``-v 2016060201``.

In the example above, a few warning messages appear. Fpm's job is to help you convert packages. In this case, we're converting a Perl module named "Regexp::Common" to a Debian package. In this situation, we need to make sure our Debian package is accepted by Debian's tools! This means fpm will do the following:

* Debian package names appear to all use lowercase names, so fpm does this for you.
* Debian package names also cannot have "::" in the names, so fpm replaces these with a dash "-"

Let's try to use our new package! First, installing it::

  % sudo dpkg -i perl-regexp-common_2017060201_all.deb
  Selecting previously unselected package perl-regexp-common.
  (Reading database ... 81209 files and directories currently installed.)
  Preparing to unpack perl-regexp-common_2017060201_all.deb ...
  Unpacking perl-regexp-common (2017060201) ...
  Setting up perl-regexp-common (2017060201) ...
  Processing triggers for man-db (2.9.1-1) ...

And try to use it. Let's ask Regexp::Common for a regular expression that matches real numbers::

  % perl -MRegexp::Common -e 'print $RE{num}{real}'
  (?:(?i)(?:[-+]?)(?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[-+]?)(?:[0123456789]+))|))

Nice!

Fun Examples
------------

.. note::
  Do you have any examples you want to share that use the ``cpan`` package type? Share your knowledge here: https://github.com/jordansissel/fpm/issues/new

cpan-specific command line flags
-------------------------------

.. include:: cli/cpan.rst
