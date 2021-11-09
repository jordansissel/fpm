npm - Packages for NodeJS
===============================

Supported Uses in FPM
---------------------

fpm supports using ``npm`` only as an input type.

Arguments when used as input type
---------------------------------

Any number of arguments are supported and behave as follows:

* ``name@version`` -- a specific named package at the given version.
* ``name`` -- the name of a node package. In this use, the ``--version`` flag is used to pick the version to download. If no version is given, the latest version of the package is downloaded.

Sample Usage
------------

You'll need ``npm`` installed for this example.

Let's turn the ``ascii-art`` npm package into a Debian package. For this example, we'll pick a specific version, 2.8.5::

  % fpm --debug -s npm -t deb --depends nodejs ascii-art@2.8.5
  Created package {:path=>"node-ascii-art_2.8.5_amd64.deb"}

Fpm uses ``npm`` to download the correct package. Additionally, the package name is given a ``node-`` prefix because this is common in distribution packages to prefix a library with the platform name, such as ``python-foo`` or ``node-foo``.

It also parses the package's ``package.json`` to collect any useful data such as the package name, author, homepage, description, etc::

  % dpkg --field node-ascii-art_2.8.5_amd64.deb Package Version Vendor Homepage Description
  Package: node-ascii-art
  Version: 2.8.5
  Vendor: Abbey Hawk Sparrow <@khrome>
  Homepage: git://github.com/khrome/ascii-art.git
  Description: Ansi codes, figlet fonts, and ascii art. 100% JS

Let's install the package and try to use it::

  % sudo apt-get install ./node-ascii-art_2.8.5_amd64.deb

And now we can use this package::

  % ascii-art text -F Doom "Hello World"
   _   _        _  _          _    _               _      _
  | | | |      | || |        | |  | |             | |    | |
  | |_| |  ___ | || |  ___   | |  | |  ___   _ __ | |  __| |
  |  _  | / _ \| || | / _ \  | |/\| | / _ \ | '__|| | / _` |
  | | | ||  __/| || || (_) | \  /\  /| (_) || |   | || (_| |
  \_| |_/ \___||_||_| \___/   \/  \/  \___/ |_|   |_| \__,_|

Fpm asked ``npm`` where to install things using ``npm prefix -g``. On my system, this caused the package to install to ``/usr/local/lib/node_modules``. You can change the default prefix with the fpm ``--prefix`` flag or by changing the default global prefix in the ``npm`` tool.

Let's try to invoke ``ascii-art`` from node::

  % export NODE_PATH=/usr/local/lib/node_modules
  % node
  > let art = require("ascii-art")
  > art.font("Hello", "Doom", (err, rendered) => console.log(rendered))
   _   _        _  _
  | | | |      | || |
  | |_| |  ___ | || |  ___
  |  _  | / _ \| || | / _ \
  | | | ||  __/| || || (_) |
  \_| |_/ \___||_||_| \___/

Nice :)

Fun Examples
------------

.. note::
  Do you have any examples you want to share that use the ``npm`` package type? Share your knowledge here: https://github.com/jordansissel/fpm/issues/new

npm-specific command line flags
-------------------------------

.. include:: cli/npm.rst
