`rpm` - RPM Packages
====================

Synopsis::

  fpm -s rpm [other options] path-to-rpm

Using 'rpm' as a source lets you treat an existing package as a source for
building a
new one.  This can be useful for converting packages between formats or
for "editing" upstream packages.

Strip out docs under `/usr/share/doc`::

  fpm -t rpm -s rpm --exclude /usr/share/doc ruby-2.0.0.x86_64.rpm`

Rename a package and assign different version::

  fpm -t rpm -s rpm --name myruby --version $(date +%S) ruby-2.0.0.x86_64.rpm

Convert an rpm in to a deb::

  fpm -t deb -s rpm fpm-1.63.x86_64.rpm
