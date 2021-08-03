Installation
============

FPM is written in ruby and can be installed using `gem`. For some package formats (like snap), you will need certain packages installed to build them.

Installing FPM
--------------

.. note::
	You must have ruby installed on your machine before installing fpm. `Here` are instructions to install Ruby on your machine.

.. _Here: https://www.ruby-lang.org/en/documentation/installation/

You can install FPM with the ``gem`` tool::

    gem install fpm

To make sure fpm is installed correctly, try running the following command::

    fpm --version

You should get some output like this, although the exact output will depend on which version of FPM you have installed.::

    % fpm --version
    1.13.1

Now you can go on to :doc:`using FPM! <getting-started>`

Installing optional dependencies
--------------------------------

.. warning::
	This section may be imperfect; please make sure you are installing the right package for your OS.

Some package formats require other tools to be installed on your machine to be built; especially if you are building a package for another operating system/distribution.

* RPM: rpm/rpm-tools/rpm-build
* Snap: squashfs/squashfs-tools

.. note::
	You will not be able to build an osxpkg package (.pkg) for MacOS unless you are running MacOS.

Here are instructions to install these dependencies on your machine:

On OSX/macOS::

    brew install gnu-tar
    brew install rpm squashfs

On Arch Linux and Arch-based systems (Manjaro, EndeavourOS, etc)::

		pacman -S base-devel ruby rpm-tools squashfs-tools

On Debian and Debian-based systems (Ubuntu, Linux Mint, Pop!_OS, etc)::

    apt-get install ruby ruby-dev rubygems build-essential squashfs-tools

On Red Hat systems (Fedora 22 or older, CentOS, Rocky Linux, etc)::

    yum install ruby-devel gcc make rpm-build rubygems squashfs-tools

On Fedora 23 or newer::

    dnf install ruby-devel gcc make rpm-build libffi-devel squashfs-tools

On Oracle Linux 7.x systems::

    yum-config-manager --enable ol7_optional_latest
    yum install ruby-devel gcc make rpm-build rubygems squashfs-tools
