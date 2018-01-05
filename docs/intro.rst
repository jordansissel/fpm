What is FPM?
===================

fpm is a command-line program designed to help you build packages.

Building a package might look something like this:

    fpm -s <source type> -t <target type> [list of sources]...

"Source type" is what your package is coming from; a directory (dir), a rubygem
(gem), an rpm (rpm), a python package (python), a php pear module (pear), see
the `full list`_.

.. _full list: https://fpm.readthedocs.io/en/latest/packages.html

"Target type" is what your output package form should be. Most common are "rpm"
and "deb" but others exist (solaris, etc)

You have a few options for learning to run FPM:

1. If you're impatient, just scan through `fpm --help`; you'll need various
   options, and we try to make them well-documented. Quick learning is
   totally welcome, and if you run into issues, you are welcome to ask
   questions in #fpm on freenode irc or on fpm-users@googlegroups.com!
2. `The documentation`_ has explanations and examples. If you run into
   problems, I welcome you to ask questions in #fpm on freenode irc or on
   fpm-users@googlegroups.com!

.. _The documentation: http://fpm.readthedocs.io/en/latest/intro.html

To give you an idea of what fpm can do, here's a few use cases:

Take a directory and turn it into an RPM::
  fpm -s dir -t rpm ...

Convert a .deb into an rpm::
  fpm -s deb -t rpm ...

Convert a rubygem into a deb package::
  fpm -s gem -t deb ...

Convert a .tar.gz into an OSX .pkg file::
  fpm -s tar -t osxpkg

Convert a .zip into an rpm::
  fpm -s zip -t rpm ...

Change properties of an existing rpm::
  fpm -s rpm -t rpm

Create an deb that automatically installs a service::
  fpm -s pleaserun -t deb

Below is a 10-minute video demonstrating fpm's simplicity of use:

.. raw:: html

    <iframe width="560" height="315" src="https://www.youtube.com/embed/Jf89-2gWwiI" frameborder="0" allowfullscreen></iframe>


Now that you've seen a bit of what fpm can do, it's time to :doc:`install fpm <installing>`.
