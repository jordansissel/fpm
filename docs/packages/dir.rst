dir - Local Files
=================

Supported Uses in FPM
---------------------

fpm supports using ``dir`` as an input type and output type. This means you can use ``dir`` to put files into other package types (like Debian or Red Hat packages). You can also use this as an output type to extract files from packages.

Arguments when used as input type
---------------------------------

Any number of arguments are supported and behave as follows:

1) A path to a local file or directory will be put into the output package as-is with the same path, contents, and metadata (file owner, modification date, etc)
2) A syntax of "localpath=destinationpath" to copy local paths into the output package with the destination path.

The local file paths are modified by the ``--chdir`` flag. The destination file paths are modified by the `--prefix`` flag.

Sample Usage
------------

For this example, let's look at packaging the Kubernetes tool, ``kubectl``. The installation for ``kubectl`` recommends downloading a pre-compiled binary. Let's do this and then package it into a Debian package.

First, we download the ``kubectl`` binary, according to the kubernetes documentation for kubectl installation on Linux::

  # Query the latest version of kubectl and store the value in the 'version' variable
  % version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

  # Download the Linux amd64 binary
  % curl -LO "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  # Make it executable
  % chmod 755 kubectl

The above shell will find the latest version of ``kubectl`` and download it. We'll use the file and the version number next to make our package::

  # Create the package that installs kubectl as /usr/bin/kubectl
  % fpm -s dir -t deb -n kubectl -a amd64 -v ${version#v*} kubectl=/usr/bin/kubectl
  Created package {:path=>"kubectl_v1.22.3_amd64.deb"}

.. note::
  We use ``${version#v*}`` in our shell to set the package version. This is
  because Kuberenetes versions have a text that starts with "v" and this is not
  valid in Debian packages. This will turn "v1.2.3" into "1.2.3" for our package.

Now we can check our package to make sure it looks the way we want::

  % dpkg --contents kubectl_1.22.3_amd64.deb
  [ ... output abbreviated for easier reading ... ]
  -rw-r--r-- 0/0        46907392 2021-11-05 20:09 ./usr/bin/kubectl

  % dpkg --field kubectl_1.22.3_amd64.deb Package Version Architecture
  Package: kubectl
  Version: 1.22.3
  Architecture: amd64

And install it to test things and make sure it's what we wanted::

  % sudo dpkg -i kubectl_1.22.3_amd64.deb
  Selecting previously unselected package kubectl.
  (Reading database ... 58110 files and directories currently installed.)
  Preparing to unpack kubectl_1.22.3_amd64.deb ...
  Unpacking kubectl (1.22.3) ...
  Setting up kubectl (1.22.3) ...

And try to use it::

  % which kubectl
  /usr/bin/kubectl

  % kubectl version
  Client Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.3", GitCommit:"c92036820499fedefec0f847e2054d824aea6cd1", GitTreeState:"clean", BuildDate:"2021-10-27T18:41:28Z", GoVersion:"go1.16.9", Compiler:"gc", Platform:"linux/amd64"}

Cool :)

Fun Examples
------------

.. note::
  Do you have any examples you want to share that use the ``dir`` package type? Share your knowledge here: https://github.com/jordansissel/fpm/issues/new
