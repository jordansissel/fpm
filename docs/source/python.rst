`python` - Python packages
==========================

Minimal example
---------------

Here's a simple example to download the `pyramid` python package and convert it to an rpm::

    % fpm -s python -t rpm pyramid
    Trying to download pyramid (using easy_install)
    Searching for pyramid
    Reading http://pypi.python.org/simple/pyramid/
    Reading http://docs.pylonshq.com
    Reading http://docs.pylonsproject.org
    Best match: pyramid 1.0
    ...
    Created /home/jls/python-pyramid-1.0.noarch.rpm

This will download the latest 'pyramid' python module using easy_install and
convert it to an rpm. It will create a package named
'python-pyramid-VERSION_ARCH.rpm' with appropriate version/arch in place.

Check the package::

    % rpm -qip python-pyramid-1.0.noarch.rpm
    Name        : python-pyramid               Relocations: (not relocatable)
    Version     : 1.0                               Vendor: (none)
    Release     : 1                             Build Date: Mon 16 May 2011 06:41:16 PM PDT
    Install Date: (not installed)               Build Host: snack.home
    Group       : default                       Source RPM: python-pyramid-1.0-1.src.rpm
    Size        : 2766900                          License: BSD-derived (http://www.repoze.org/LICENSE.txt)
    Signature   : (none)
    URL         : http://docs.pylonsproject.org
    Summary     : The Pyramid web application framework, a Pylons project
    Description :
    The Pyramid web application framework, a Pylons project

From the above, you can see that fpm automatically picked the package name,
version, maintainer, homepage, and description all from the python package
itself.  Nothing for you to worry about :)

Looking at the dependencies::

     % rpm -qRp python-pyramid-1.0.noarch.rpm
     python-Chameleon >= 1.2.3
     python-Mako >= 0.3.6
     python-Paste > 1.7
     python-PasteDeploy >= 0
     python-PasteScript >= 0
     python-WebOb >= 1.0
     python-repoze.lru >= 0
     python-setuptools >= 0
     python-zope.component >= 3.6.0
     python-zope.configuration >= 0
     python-zope.deprecation >= 0
     python-zope.interface >= 3.5.1
     python-venusian >= 0.5
     python-translationstring >= 0
     rpmlib(PayloadFilesHavePrefix) <= 4.0-1
     rpmlib(CompressedFileNames) <= 3.0.4-1

Packaging for multiple pythons
-------------------------------

Some systems package python with packages named 'python24' and 'python26' etc. 

You can build packages like this with fpm using the `--python-package-name-prefix` flag::

    % ruby bin/fpm -s python -t rpm --python-package-name-prefix python26 pyramid
    ...
    Created /home/jls/projects/fpm/python26-pyramid-1.0.noarch.rpm

    % rpm -qRp python26-pyramid-1.0.noarch.rpm
    python26-Chameleon >= 1.2.3
    python26-Mako >= 0.3.6
    python26-Paste > 1.7
    python26-PasteDeploy >= 0
    <remainder of output trimmed... you get the idea>

You can ask for a specific version with '-v <VERSION>'. It will also handle
dependencies. Here's an example converting an older package like pysqlite version 2.5.6::

    % fpm -s python -t rpm --python-package-name-prefix python26 -v 2.5.6 'pysqlite'
    Trying to download pysqlite (using easy_install)
    Searching for pysqlite==2.5.6
    Reading http://pypi.python.org/simple/pysqlite/
    Reading http://pysqlite.googlecode.com/
    < ... output cut ... >
    Created /home/jls/projects/fpm/python26-pysqlite-2.5.6.x86_64.rpm

Local python sources
--------------------

If you are the developer of a python package, or you already have the local
package downloaded and unpacked.

In this scenario, you can tell fpm to use the `setup.py`::

    % ls pyramid/setup.py
    pyramid/setup.py

    % fpm -s python -t rpm pyramid/setup.py
    ...
    Created /tmp/python-pyramid-1.0.noarch.rpm

