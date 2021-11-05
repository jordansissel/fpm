empty - A package with no files
===============================

Supported Uses in FPM
---------------------

fpm supports using ``empty`` only as an input type.  

Arguments when used as input type
---------------------------------

Extra arguments are ignored for this type. As an example, where with ``fpm -s dir ...`` the arguments are file paths, ``fpm -s empty`` takes no input arguments because there's no file contents to use.

Sample Usage
------------

The ``empty`` package type is great for creating "meta" packages which are used to group dependencies together.

For example, if you want to make it easier to install a collection of developer tools, you could create a single package that depends on all of your desired developer tools. 

Let's create a Debian package named 'devtools' which installs the following:

* git
* curl
* nodejs

Here's the fpm command to do this::

  % fpm -s empty -t rpm -n devtools -a all -d git -d curl -d nodejs
  Created package {:path=>"devtools-1.0-1.noarch.rpm"}

We can check the dependencies on this package and also see that there are no files::

  % dpkg --field devtools_1.0_all.deb Depends
  git, curl, nodejs

  % dpkg --contents devtools_1.0_all.deb 
  drwxrwxr-x 0/0               0 2021-11-04 22:38 ./
  drwxr-xr-x 0/0               0 2021-11-04 22:38 ./usr/
  drwxr-xr-x 0/0               0 2021-11-04 22:38 ./usr/share/
  drwxr-xr-x 0/0               0 2021-11-04 22:38 ./usr/share/doc/
  drwxr-xr-x 0/0               0 2021-11-04 22:38 ./usr/share/doc/devtools/
  -rw-r--r-- 0/0             135 2021-11-04 22:38 ./usr/share/doc/devtools/changelog.gz

Fun Examples
------------

Hi! The fpm project would love to have any fun examples you have for using this package type. Please consider contributing your ideas by submitting them on the fpm issue tracker: https://github.com/jordansissel/fpm/issues/new
