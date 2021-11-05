deb - Debian package format
===========================

Supported Uses in FPM
---------------------

fpm supports input and output for Debian package (deb). This means you can read a deb and convert it to a different output type (such as a `dir` or `rpm`). It also means you can create a deb package.

Arguments when used as input type
---------------------------------

For the sample command reading a deb file as input and outputting an rpm package::

	fpm -s deb -t rpm file.deb

The argument is used as a file and read as a debian package file.

Sample Usage
------------

Let's create a Debian package of Hashicorp's Terraform. To do this, we'll need to download it and put the files into a Debian package::

    # Download Terraform 1.0.10
    % wget https://releases.hashicorp.com/terraform/1.0.10/terraform_1.0.10_linux_amd64.zip

The Terraform release .zip file contains a single file, `terraform` itself. You can see the files in this zip by using `unzip -l`::

    % unzip -l ~/build/z/terraform_1.0.10_linux_amd64.zip
    Archive:  /home/jls/build/z/terraform_1.0.10_linux_amd64.zip
      Length      Date    Time    Name
    ---------  ---------- -----   ----
    79348596  2021-10-28 07:15   terraform
    ---------                     -------
    79348596                     1 file

We can use fpm to convert this zip file into a debian package with one step::

    % fpm -s zip -t deb --prefix /usr/bin -n terraform -v 1.0.10 terraform_1.0.10_linux_amd64.zip
    Created package {:path=>"terraform_1.0.10_amd64.deb"}

Nice! We just converted a zip file into a debian package. Let's talk through the command-line flags here:

* ``-s zip`` tells fpm to use "zip" as the input type. This allows fpm to read zip files.
* ``-t deb`` tells fpm to output a Debian package.
* ``--prefix /usr/bin`` tells fpm to move all files in the .zip file to the /usr/bin file path. In this case, it results in a single file in the path `/usr/bin/terraform`
* ``-n terraform`` names the package "terraform"
* ``-v 1.0.10`` sets the package version. This is useful to package systems when considering whether a given package is an upgrade, downgrade, or already installed.
* Finally, the last argument, `terraform_1.0.10_linux_amd64.zip`. This is given to the fpm to process as a zip file.

You can inspect the package contents with `dpkg --contents terraform_1.0.10_amd64.deb`::

    % dpkg --contents terraform_1.0.10_amd64.deb
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./usr/
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./usr/share/
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./usr/share/doc/
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./usr/share/doc/terraform/
    -rw-r--r-- 0/0             141 2021-11-02 23:33 ./usr/share/doc/terraform/changelog.gz
    drwxr-xr-x 0/0               0 2021-11-02 23:33 ./usr/bin/
    -rwxr-xr-x 0/0        79348596 2021-10-28 07:15 ./usr/bin/terraform

The ``changelog.gz`` file is a recommended Debian practice for packaging. FPM will provide a generated changelog for you, by default. You can provide your own with the ``--deb-changelog`` flag.

Lets install our terraform package and try it out::

    % sudo apt install ./terraform_1.0.10_amd64.deb
    ...

    % dpkg -l terraform
    Desired=Unknown/Install/Remove/Purge/Hold
    | Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
    |/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
    ||/ Name                     Version           Architecture      Description
    +++-========================-=================-=================-=====================================================
    ii  terraform                1.0.10            amd64             no description given

    % terraform -version
    Terraform v1.0.10
    on linux_amd64

You may remove the package at any time::

    % sudo apt remove terraform
    ...
    Removing terraform (1.0.10) ...


Fun Examples
------------

Hi! The fpm project would love to have any fun examples you have for using this package type. Please consider contributing your ideas by submitting them on the fpm issue tracker: https://github.com/jordansissel/fpm/issues/new

Changing an existing deb
~~~~~~~~~~~~~~~~~~~~~~~~

fpm supports deb as both an input and output type (``-s`` and ``-t`` flags), so you can use this to modify an existing deb.

For example, let's create an deb to use for our example::

  % fpm -s empty -t deb -n example
  Created package {:path=>"example_1.0_amd64.deb"}

Lets say we made a mistake and want to rename the package::

  % fpm -s deb -t deb -n newname example_1.0_amd64.deb
  Created package {:path=>"newname_1.0_amd64.deb"}

And maybe the architecture is wrong. fpm defaulted to amd64 (what fpm calls
"native"), and we really want what Debian calls "all"::

  % fpm -s deb -t deb -a all newname_1.0_amd64.deb
  Created package {:path=>"newname_1.0_all.deb"}

Deb-specific command line flags
-------------------------------

.. include:: cli/deb.rst
