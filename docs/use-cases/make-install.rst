nodejs and multiple packages
=====================================================

This example requires your `make install` support setting DESTDIR or otherwise
allow you to install to a specific target directory.

Consider building nodejs. Sometimes you want to produce multiple packages from
a single project. In this case, building three separate packages: nodejs, nodejs-dev, and nodejs-doc.

Package up the nodejs runtime
-----------------------------

Normal build steps::

    # Normal build steps.
    % wget http://nodejs.org/dist/v0.6.0/node-v0.6.0.tar.gz
    % tar -zxf node-v0.6.0.tar.gz
    % cd node-v0.6.0
    % ./configure --prefix=/usr
    % make

Now install it to a temporary directory::

    # Install to a separate directory for capture.
    % mkdir /tmp/installdir
    % make install DESTDIR=/tmp/installdir

Now make the 'nodejs' package::

    # Create a nodejs deb with only bin and lib directories:
    # The 'VERSION' and 'ARCH' strings are automatically filled in for you
    # based on the other arguments given.
    % fpm -s dir -t deb -n nodejs -v 0.6.0 -C /tmp/installdir \
      -p nodejs_VERSION_ARCH.deb \
      -d "libssl0.9.8 > 0" \
      -d "libstdc++6 >= 4.4.3" \
      usr/bin usr/lib

Install the package, test it out::

    # 'fpm' just produced us a nodejs deb:
    % file nodejs_0.6.0-1_amd64.deb
    nodejs_0.6.0-1_amd64.deb: Debian binary package (format 2.0)
    % sudo dpkg -i nodejs_0.6.0-1_amd64.deb 

    % /usr/bin/node --version
    v0.6.0

Package up the manpages (create nodejs-doc)
-------------------------------------------
Now, create a package for the node manpage::
    
    # Create a package of the node manpage
    % fpm -s dir -t deb -p nodejs-doc_VERSION_ARCH.deb -n nodejs-doc -v 0.6.0 -C /tmp/installdir usr/share/man

Look in the nodejs-doc package::

    % dpkg -c nodejs-doc_0.6.0-1_amd64.deb| grep node.1
    -rw-r--r-- root/root       945 2011-01-02 18:35 usr/share/man/man1/node.1

Package up the headers (create nodejs-dev)
------------------------------------------
Lastly, package the headers for development::

Package up the headers via::

    % fpm -s dir -t deb -p nodejs-dev_VERSION_ARCH.deb -n nodejs-dev -v 0.6.0 -C /tmp/installdir usr/include  
    % dpkg -c nodejs-dev_0.6.0-1_amd64.deb | grep -F .h 
    -rw-r--r-- root/root     14359 2011-01-02 18:33 usr/include/node/eio.h
    -rw-r--r-- root/root      1118 2011-01-02 18:33 usr/include/node/node_version.h
    -rw-r--r-- root/root     25318 2011-01-02 18:33 usr/include/node/ev.h
    ...

Yay!

