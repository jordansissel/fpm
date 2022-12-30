Getting Started
===============

FPM takes your program and builds packages that can be installed easily on various operating systems.

Understanding the basics of FPM
-------------------------------

The ``fpm`` command takes in three arguments:

* The type of sources to include in the package
* The type of package to output
* The sources themselves

The source could be a:

* file OR a directory with various files needed to run the program - ``dir``
* nodejs (npm) package - ``npm``
* ruby (gem) package - ``gem``
* python (using easy_install or a local setup.py) package - ``python``
* python virtualenv - ``virtualenv``
* pear package - ``pear``
* perl (cpan) module - ``cpan``
* .deb package - ``deb``
* .rpm package - ``rpm``
* pacman (.pkg.tar.zst) package - ``pacman``
* .pkgin package - ``pkgin``
* package without any files (useful for meta packages) - ``empty``

The target (output package format) could be:

* A .deb package (for Debian and Debian-based) - ``deb``
* A .rpm package (for RedHat based) - ``rpm``
* A .solaris package (for Solaris) - ``solaris``
* A .freebsd package (for FreeBSD) - ``freebsd``
* MacOS .pkg files - ``osxpkg``
* Pacman packages (.pkg.tar.zst) (for Arch Linux and Arch-based) - ``pacman``
* A puppet module - ``puppet``
* A p5p module - ``p5p``
* A self-extracting installer - ``sh``
* A tarfile that can be extracted into the root of any machine to install the program - ``tar``
* A zipfile that can be extracted into the root of any machine to install the program - ``zip``
* A directory that can be copied to the root of any machine to install the program - ``dir``

Given a source and a target, FPM can convert all the source files into a package of the target format.

Using it to package an executable
---------------------------------

To simplyify things a bit, let's take an example. Suppose you have a bash script that prints 'Hello, world!' in multiple colors when it is run::

	--- File: hello-world

	#!/usr/bin/env bash
	
	#
	# == hello-world 0.1.0 ==
	#

	echo "Hello, world!" | lolcat

Let's say you even wrote a manpage (manual page) for it::

	--- File: hello-world.1
	
	.TH HELLO WORLD "1" "July 2021" "hello-world 0.1.0" "User Commands"
	.SH NAME
	hello-world \- manual page for hello-world 0.1.0
	.SH DESCRIPTION
	.IP
	USAGE: hello-world
	.SH "SEE ALSO"
	.IP
	Website: https://example.com/hello-world
	.SH "OTHER"
	.IP
	Made by You The Amazing Person <you are an amazing person at example dot com>
	.IP
	This program is distributed under the AGPL 3.0 license.

Now you want to package this script and its manual page and distribute to the world as a .deb file. To do that using FPM, here is the command we need to run::

	fpm \
	  -s dir -t deb \
	  -p hello-world-0.1.0-1-any.deb \
	  --name hello-world \
	  --license agpl3 \
	  --version 0.1.0 \
	  --architecture all \
	  --depends bash --depends lolcat \
	  --description "Say hi!" \
	  --url "https://example.com/hello-world" \
	  --maintainer "You The Amazing Person <you are an amazing person at example dot com>" \
	  hello-world=/usr/bin/hello-world hello-world.1=/usr/share/man/man1/hello-world.1

If you have installed FPM, and have the hello-world script in your current directory, you should be able to see a ``hello-world-0.1.0-1-any.deb`` file in your current directory after you run this command.

Let's break the command down, option by option:

* ``-s dir`` [required]
	- The ``-s`` option tells FPM what sources to use to build the package.
	- In this case [``dir``], we are telling FPM that we want to build a package from source files that we have on our computer.

* ``-t deb`` [required]
	- The ``-t`` option tells FPM what type of package to build (target package).
	- In this case [``deb``], we are telling FPM that we want to build a .deb package, that can be installed on Debian and Debian-based operating systems, such as Ubuntu.

* ``-p hello-world-0.1.0-1-any.deb``
	- The ``-p`` option tells FPM what to name the package once it has been created.
	- In this case, we name it ``<package name>-<version>-<package rel/iteration>-<architecture>.<file extension>``, but you can call it whatever you want.

* ``--name hello-world``
	- The name of the program that FPM is packaging.
	- In this case, it is hello-world.

* ``--license agpl3``
	- The license the program uses
	- In this case, we use the AGPL 3.0 license (If you have a custom license, use ``custom`` instead of AGPL3)

* ``--version 0.1.0``
	- The version of the program
	- In this case, the version is 0.1.0

* ``--architecture all``
	- The architecture required to run the program [valid values are: x86_64/amd64, aarch64, native (current architecture), all/noarch/any]
	- In this case, the program is just a bash script, so we can run on all architectures

* ``--depends bash --depends lolcat``
	- The dependencies the program needs to run 
	- In this case, we need bash and lolcat - bash to run the program itself, and lolcat to display the text in multiple colors

* ``--description "Say hi!"``
	- The program description
	- In this case, it is Say hi!

* ``--url "https://example.com/hello-world"``
	- The URL to the program``s website or URL to program source

* ``--maintainer "You The Amazing Person <you are an amazing person at example dot com>"``
	- The name and (optionally) email of the person creating the package

* ``hello-world=/usr/bin/hello-world hello-world.1=/usr/share/man/man1/hello-world.1`` [required]
	- This is the most important part. It tells FPM which file (relative paths from the current directory) should be installed to which path in the machine.
	- In this case, we want the user to be able to execute the command ``hello-world`` from terminal; so we put the hello-world script in the user's PATH, that is, in /usr/bin/. We also want the user to access the manual page using ``man hello-world``, so we put the manpage (hello-world.1) in the /usr/share/man/man1/ directory.

For more detailed documentation about each and every flag (there are some package-type-specific flags that exist as well), run ``fpm --help``.

Using it to package an existing package
---------------------------------------

We've seen how to package a program if you have an executable, but what if you already have a program that you have not written as an executable script, but in a language like nodejs instead? FPM can help here too. It can take any nodejs package, ruby gem or even a python package and turn it into a deb, rpm, pacman, etc. package. Here are a couple of examples.

Packaging a NodeJS application that's already on NPM
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::
	This assumes you have nodejs and npm already installed on your machine.

Run the following command::

	fpm -s npm -t <deb/rpm/pacman/solaris/freebsd/osxpkg/tar> <npm-package-name>

E.g.: To package yarn for Arch Linux::

	fpm -s npm -t pacman yarn

This will download the latest ``yarn`` package from npm.com and convert it to a .pkg.tar.zst (pacman) package. It will create a package named ‘node-yarn-VERSION_ARCH.deb’ with the appropriate version/arch in place. FPM will automatically pick the package name, version, maintainer, section, homepage, and description all from the npm package itself. Nothing for you to worry about :)

Packaging a ruby gem
~~~~~~~~~~~~~~~~~~~~

.. note::
	This assumes you have ruby already installed on your machine.

Run the following command::

	fpm -s gem -t <deb/rpm/pacman/solaris/freebsd/osxpkg/tar> <gem-name>

E.g.: To package FPM using FPM for Debian::

	# FPM-ception :D
	fpm -s gem -t deb fpm

This will download the latest ``fpm`` rubygem from rubygems.org and convert it to a .deb. It will create a package named ‘rubygem-fpm-VERSION_ARCH.deb’ with the appropriate version/arch in place. FPM will automatically pick the package name, version, maintainer, section, homepage, and description all from the rubygem itself. Nothing for you to worry about :)

Packaging a CPAN module
~~~~~~~~~~~~~~~~~~~~~~~

.. note::
	This assumes you have perl already installed on your machine.

Run the following command package the perl Fennec module for Debian::

	fpm -s cpan -t deb Fennec

This will download Fennec from CPAN and build a Debian package of the Fennec Perl module locally.

By default, FPM believes the following to be true:

* That your local Perl lib path will be the target Perl lib path
* That you want the package name to be prefixed with the word perl
* That the dependencies from CPAN are valid and that the naming scheme for those dependencies are prefixed with perl

If you wish to change any of the above, use the following::

	fpm -t deb -s cpan -–cpan-perl-lib-path /usr/share/perl5 Fennec

	fpm -t deb -s cpan --cpan-package-name-prefix fubar /usr/share/perl5 Fennec

The first command will change the target path to where perl will be. Your local perl install may be /opt/usr/share/perl5.10 but the package will be constructed so that the module will be installed to /usr/share/perl5

The second command will change the prefix of the package, i.e., from perl-Fennec to fubar-Fennec.

Configuration file
-------------------

If you are using FPM in to build packages for multiple targets and keep repeating several options (like version, description, name, license, maintainer, url, architecture, files to package, etc.), you can add a ``.fpm`` file in your working directory, with a list of options as well as arguments that you want to pass to the CLI. Extending the example of the hello-world program, say we want to package it as a .deb and a .rpm. We could create the following .fpm file::

	--- File: .fpm

	-s dir
	--name hello-world
	--license agpl3
	--version 0.1.0
	--architecture all
	--depends bash --depends lolcat
	--description "Say hi!"
	--url "https://example.com/hello-world"
	--maintainer "You The Amazing Person <you are an amazing person at example dot com>"

	hello-world=/usr/bin/hello-world hello-world.1=/usr/share/man/man1/hello-world.1

.. note::
	CLI flags will override those in the ``.fpm`` file.

Meanwhile, we could run the following commands in terminal to build the .deb and .rpm::

	fpm -t deb -p hello-world-0.1.0-1-any.deb

	fpm -t rpm -p hello-world-0.1.0-1-any.rpm

Tada! You will have a .deb (for Debian) and .rpm (for RedHat), with no unnecessary duplication of metadata. You can put any other valid CLI options in the ``.fpm`` file too.

For more detailed information regarding all CLI flags, see the :doc:`CLI reference. <cli-reference>`
