# Effing Package Management.

## Preface

Package maintainers work hard and take a lot of shit. You can't please everyone. So, if you're a maintainer: Thanks for maintaining packages!

## Backstory

Sometimes packaging is done wrong (because you can't do it right for all
situations), but small tweaks can fix it.

And sometimes, there isn't a package available for the tool you need.

And sometimes if you ask "How do I get python 3 on CentOS 5?" some unhelpful
trolls will tell you to "Use another distro"

Further, a recent job switch has me now using Ubuntu for production while prior
was CentOS. These use two totally different package systems with completely different
packaging policies and support tools. It was painful and confusing learning both. I
want to save myself (and you) that pain in the future.

It should be easy to say "here's my install dir and here's some dependencies;
please make a package"

## The Solution - FPM

I want a simple way to create packages without all the bullshit. In my own
infrastructure, I have no interest in Debian policy and RedHat packaging
guidelines - I have interest in my group's own style culture and have a very strong
interest in getting work done.

The goal of FPM is to be able to easily build platform-native packages.

* Creating packages easily (deb, rpm, etc)
* Tweaking existing packages (removing files, changing metadata/dependencies)
* Stripping pre/post/maintainer scripts from packages

## Get with the download

You can install fpm with gem:

    gem install fpm

It ships with 'fpm' and 'fpm-npm' tools.

## The State

I currently only support producing deb packages, but rpm and other package
support would be trivial - I just need time or patches.

## Things that are in the works or should work:

Sources:

* gem (even autodownloaded for you)
* directories
* rpm
* node packages (npm)

Targets:

* deb
* rpm

## Use case: Package up an installation.

    # Normal build steps.
    % wget http://nodejs.org/dist/node-v0.3.3.tar.gz
    % tar -zxf node-v0.3.3.tar.gz 
    % ./configure --prefix=/usr
    % make

    # Install to a separate directory for capture.
    % mkdir /tmp/installdir
    % make install DESTDIR=/tmp/installdir

    # Create a nodejs deb with only bin and lib directories:
    # The 'VERSION' and 'ARCH' strings are automatically filled in for you
    # based on the other arguments given.
    % fpm -n nodejs -v 0.3.3 -C /tmp/installdir \
      -p nodejs-VERSION_ARCH.deb \
      -d "libssl0.9.8 (> 0)" \
      -d "libstdc++6 (>= 4.4.3)" \
      usr/bin usr/lib

    # 'fpm' just produced us a nodejs deb:
    % file file nodejs-0.3.3-1_amd64.deb
    nodejs-0.3.3-1_amd64.deb: Debian binary package (format 2.0)
    % sudo dpkg -i nodejs-0.3.3-1_amd64.deb 

    % /usr/bin/node --version
    v0.3.3

    # Create a package of the node manpage
    % fpm -p nodejs-doc-VERSION_ARCH.deb -n nodejs -v 0.3.3 -C /tmp/installdir usr/share/man

    # Look in the package:
    % dpkg -c nodejs-doc-0.3.3-1_amd64.deb| grep node.1
    -rw-r--r-- root/root       945 2011-01-02 18:35 usr/share/man/man1/node.1

    # Create the -dev package:
    % fpm -p nodejs-dev-VERSION_ARCH.deb -n nodejs -v 0.3.3 -C /tmp/installdir usr/include  
    % dpkg -c nodejs-dev-0.3.3-1_amd64.deb | grep -F .h 
    -rw-r--r-- root/root     14359 2011-01-02 18:33 usr/include/node/eio.h
    -rw-r--r-- root/root      1118 2011-01-02 18:33 usr/include/node/node_version.h
    -rw-r--r-- root/root     25318 2011-01-02 18:33 usr/include/node/ev.h
    ...


## Use case: Deploying NPMs

Node has it's own package manager. Cool.

Puppet doesn't have support for npm, but it's easy to now convert npms to debs!

    # Produce .deb packages for jsdom and any dependencies.
    % fpm-npm -t deb -n jsdom
    npm info it worked if it ends with ok
    npm info using npm@0.2.13-3
    npm info using node@v0.3.1
    npm info fetch http://registry.npmjs.org/jsdom/-/jsdom-0.1.22.tgz

    ... blah blah blah ...

    # Now we have htmlparser and jsdom .deb packages
    % ls nodejs*.deb
    nodejs-htmlparser-1.7.3-1_all.deb  nodejs-jsdom-0.1.22-1_all.deb

    % dpkg --info nodejs-jsdom-0.1.23-1_all.deb
     ...
     Package: nodejs-jsdom
     Version: 0.1.23-1
     Architecture: all
     Maintainer: Elijah Insua <tmpvar@gmail.com>
     Depends: nodejs-htmlparser (= 1.7.3)
     ...

    % sudo dpkg -i nodejs-htmlparser-1.7.3-1_all.deb nodejs-jsdom-0.1.23-1_all.deb
    % dpkg -l | grep nodejs-     
    ii  nodejs-htmlparser                               1.7.3-1
    ii  nodejs-jsdom                                    0.1.23-1

Voila.
