fpm - packaging made simple
===========================

.. note::
  The documentation here is a work-in-progress; it is by no means extensive. If you want to contribute new docs or report problems, you are invited to do so on `the project issue tracker`_.

Welcome to the fpm documentation!

fpm is a tool which lets you easily create packages for Debian, Ubuntu, Fedora, CentOS, RHEL, Arch Linux, FreeBSD, macOS, and more!

fpm isn't a new packaging system, it's a tool to help you make packages for existing systems with less effort. It does this by offering a command-line interface to allow you to create packages easily. Here are some examples using fpm:

* ``fpm -s npm -t deb express`` -- Make a Debian package for the nodejs `express` library
* ``fpm -s cpan -t rpm Fennec`` -- Make an rpm for the perl Fennec module
* ``fpm -s dir -t pacman -n fancy ~/.zshrc`` -- Put your ~/.zshrc into an Arch Linux pacman package named "fancy"
* ``fpm -s python -t freebsd Django`` -- Create a FreeBSD package containing the Python Django library
* ``fpm -s rpm -t deb mysql.rpm`` -- Convert an rpm to deb

This project has a few important principles which guide development:

* Community: If a newbie has a bad time, it's a bug.
* Engineering: Make it work, make it right, then make it fast.
* Capabilities: If it doesn't do a thing today, we can make it do it tomorrow.

`Install fpm <installation.html>`_ and you'll quickly begin making packages for whatever you need!

You can view the changelog `here`_.

Table of Contents
-----------------

.. toctree::
	:includehidden:

	installation
	getting-started
	packaging-types
	cli-reference
	docker
	contributing
	changelog

.. _here: /changelog.html

.. _the project issue tracker: https://github.com/jordansissel/fpm/issues
