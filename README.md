# Effing Package Management.

## Preface

Package maintainers work hard and take a lot of shit. You can't please everyone. So, if you're a maintainer: Thanks for maintaining packages!

## Backstory

Sometimes packaging is done wrong (because you can't do it right for all
situations), but small tweaks can fix it.

And sometimes, there isn't a package available for the tool you need.

And sometimes if you ask "How do I get python 3 on CentOS 5?" some unhelpful
trolls will tell you to "Use another distro" 

## The Solution - FPM

I want a simple way to create packages without all the bullshit. In my own
infrastructure, I have no interest in Debian policy and RedHat packaging
guidelines - I have interest in my group's own style culture and a very strong
interest in getting work done.

The goal of FPM is to be able to easily build platform-native packages.

* Creating packages easily (deb, rpm, etc)
* Tweaking existing packages (removing files, changing metadata/dependencies)
* Stripping pre/post/maintainer scripts from packages

## The State

I currently only support producing deb packages, but rpm and other package
support would be trivial - I just need time or patches.

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
    % fpm -n nodejs -v 0.3.3 -C /tmp/installdir \
      -p nodejs-VERSION_ARCH.deb \
      -d "libssl0.9.8 (> 0)" \-d "libstdc++6 (>= 4.4.3)" \
      usr/bin usr/lib

    # 'fpm' just produced us a nodejs deb:
    % file file nodejs-0.3.3-1_amd64.deb
    nodejs-0.3.3-1_amd64.deb: Debian binary package (format 2.0)
    % sudo dpkg -i nodejs-0.3.3-1_amd64.deb 

    % /usr/bin/node --version
    v0.3.3

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
