What is FPM?
===================

fpm is a tool designed to help you build packages.

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
