rpm - RedHat Package Manager
============================

rpm is the package format used on RedHat Enterprise (RHEL), Fedora, CentOS, and
a number of other Linux distributions.
 
You may be familiar with tools such as `dnf` and `yum` for installing packages from repositories. The package files that these tools install are rpms.

Supported Uses in FPM
---------------------

fpm supports input and output for rpms. This means you can read an rpm and convert it to a different output type (such as a `dir` or `deb`). It also means you can write an rpm.

Arguments when used as input type
---------------------------------

For the sample command reading an rpm as input and outputting a debian package::

	fpm -s rpm -t deb file.rpm

The the argument is used as a file and read as an rpm.

Sample Usage
------------

Create a package with no files but having dependencies::

	% fpm -s empty -t rpm -n example --depends nginx
	Created package {:path=>"example-1.0-1.x86_64.rpm"}

We can now inspect the package with rpm's tools if you wish::

	% rpm -qp example-1.0-1.x86_64.rpm -i
	Name        : example
	Version     : 1.0
	Release     : 1
	Architecture: x86_64
	Install Date: (not installed)
	Group       : default
	Size        : 0
	License     : unknown
	Signature   : (none)
	Source RPM  : example-1.0-1.src.rpm
	Build Date  : Wed 20 Oct 2021 09:43:25 PM PDT
	Build Host  : snickerdoodle.localdomain
	Relocations : /
	Packager    : <jls@snickerdoodle>
	Vendor      : none
	URL         : http://example.com/no-uri-given
	Summary     : no description given
	Description :
	no description given

Fun Examples
------------

Changing an existing RPM
~~~~~~~~~~~~~~~~~~~~~~~~

fpm supports rpm as both an input and output type (`-s` and `-t` flags), so you can use this to modify an existing rpm.

For example, let's create an rpm to use for our example::

  % fpm -s empty -t rpm -n example
  Created package {:path=>"example-1.0-1.x86_64.rpm"}

Lets say we made a mistake and want to rename the package::

  % fpm -s rpm -t rpm -n newname example-1.0-1.x86_64.rpm
  Created package {:path=>"newname-1.0-1.x86_64.rpm"}

And maybe the architecture is wrong. fpm defaulted to x86_64 (what fpm calls
"native"), and we really want what rpm calls "noarch"::

  % fpm -s rpm -t rpm -a noarch newname-1.0-1.x86_64.rpm
  Created package {:path=>"newname-1.0-1.noarch.rpm"}

RPM-specific command line flags
-------------------------------

.. include:: cli/rpm.rst
