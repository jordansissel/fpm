`virtualenv` - Python virtual environments
==========================================

Synopsis::

  fpm -s virtualenv [other options] EGG_SPEC|requirements.txt

FPM has support for building packages that provide a python virtualenv from a
single egg or from a `requirements.txt` file.  This lets you bundle up a set of
python dependencies separate from system python that you can then distribute.

.. note::
   `virtualenv` support requires that you have `virtualenv` and  the
   `virtualenv-tools` binary on your path.  This can usually be achieved with
   `pip install virtualenv virtualenv-tools`.

Example uses:
=============

Build an rpm package for ansible::

  fpm -s virtualenv -t rpm ansible
  yum install virtualenv-ansible*.rpm
  which ansible # /usr/share/python/ansible/bin/ansible

Create a debian package for your project's python dependencies under `/opt`::

  echo 'glade' >> requirements.txt
  echo 'paramiko' >> requirements.txt
  echo 'SQLAlchemy' >> requirements.txt
  fpm -s virtualenv -t deb --name myapp-python-libs \
    --prefix /opt/myapp/virtualenv requirements.txt

Create a debian package from a version 0.9 of an egg kept in your internal
pypi repository, along with it's external dependencies::

  fpm -s virtualenv -t deb \
    --virtualenv-pypi-extra-url=https://office-pypi.lan/ \
    proprietary-magic=0.9
