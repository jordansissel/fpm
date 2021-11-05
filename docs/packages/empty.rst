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

We can check the dependencies on this package::

  % rpm -qp devtools-1.0-1.noarch.rpm --requires
  curl
  git
  nodejs
  rpmlib(CompressedFileNames) <= 3.0.4-1
  rpmlib(PayloadFilesHavePrefix) <= 4.0-1

And see that there are no files::

  % rpm -ql devtools-1.0-1.noarch.rpm
  (contains no files)


Fun Examples
------------

Hi! The fpm project would love to have any fun examples you have for using this package type. Please consider contributing your ideas by submitting them on the fpm issue tracker: https://github.com/jordansissel/fpm/issues/new
