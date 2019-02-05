Installation
============

FPM requires a few things before you can use it. This document will show you
how to install all the necessary things :)

Depending on what you want to do with FPM, you might need some extra things installed (like tooling to build rpms, or solaris packages, or something else), but for now, let's just get ruby so we can start using fpm!

Installing things FPM needs
--------------

.. warning::
  This section may be imperfect due to the inconsistencies across OS vendors

fpm is written in Ruby, you'll need to provide Ruby. Some operating systems,
like OSX, come with Ruby already, but some do not. Depending on your operating system, you might need to run the following commands:

On OSX/macOS::

    brew install gnu-tar

On Red Hat systems (Fedora 22 or older, CentOS, etc)::

    yum install ruby-devel gcc make rpm-build rubygems

On Fedora 23 or newer::

    dnf install ruby-devel gcc make rpm-build libffi-devel

On Oracle Enterprise 7.x systems::

    yum-config-manager --add-repo=https://yum.oracle.com/repo/OracleLinux/OL7/optional/developer/x86_64
    yum install ruby-devel gcc make rpm-build rubygems

On Debian-derived systems (Debian, Ubuntu, etc)::

    apt-get install ruby ruby-dev rubygems build-essential

Installing FPM
--------------

You can install fpm with the `gem` tool::

    gem install --no-ri --no-rdoc fpm

.. note::
  `gem` is a command provided by a the Ruby packaging system called `rubygems`_. This allows you to install, and later upgrade, fpm.

.. _rubygems: https://en.wikipedia.org/wiki/RubyGems

You should see output that looks like this::

    % gem install --no-ri --no-rdoc fpm
    Fetching: cabin-0.9.0.gem (100%)
    Successfully installed cabin-0.9.0
    Fetching: backports-3.6.8.gem (100%)
    Successfully installed backports-3.6.8
    Fetching: arr-pm-0.0.10.gem (100%)
    Successfully installed arr-pm-0.0.10
    Fetching: clamp-1.0.1.gem (100%)
    Successfully installed clamp-1.0.1
    Fetching: ffi-1.9.14.gem (100%)
    Building native extensions.  This could take a while...
    Successfully installed ffi-1.9.14
    Fetching: childprocess-0.5.9.gem (100%)
    Successfully installed childprocess-0.5.9
    Fetching: archive-tar-minitar-0.5.2.gem (100%)
    Successfully installed archive-tar-minitar-0.5.2
    Fetching: io-like-0.3.0.gem (100%)
    Successfully installed io-like-0.3.0
    Fetching: ruby-xz-0.2.3.gem (100%)
    Successfully installed ruby-xz-0.2.3
    Fetching: dotenv-2.1.1.gem (100%)
    Successfully installed dotenv-2.1.1
    Fetching: insist-1.0.0.gem (100%)
    Successfully installed insist-1.0.0
    Fetching: mustache-0.99.8.gem (100%)
    Successfully installed mustache-0.99.8
    Fetching: stud-0.0.22.gem (100%)
    Successfully installed stud-0.0.22
    Fetching: pleaserun-0.0.27.gem (100%)
    Successfully installed pleaserun-0.0.27
    Fetching: fpm-1.6.3.gem (100%)
    Successfully installed fpm-1.6.3
    15 gems installed

Now you should be ready to use fpm!

To make sure fpm is installed correctly, try running the following command::

    fpm --version

You should get some output like this, although the exact output will depend on which version of fpm you have installed.::

    % fpm --version
    1.6.3
