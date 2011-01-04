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

## Use case: Deploying NPMs

Node has it's own package manager. Cool.

In the 'tools' directory there is 'npm2pkg.rb' (this will later be integrated
directly into fpm itself, but for now, it's an external tool):

    # Produce .deb packages for jsdom and any dependencies.
    % ruby tools/npm2pkg.rb -n jsdom
    npm info it worked if it ends with ok
    npm info using npm@0.2.13-3
    npm info using node@v0.3.1
    npm info fetch http://registry.npmjs.org/jsdom/-/jsdom-0.1.22.tgz
    npm info calculating sha1 /tmp/npm-1294108194638/1294108195883-0.10342533886432648/tmp.tgz
    npm info shasum 2914b514083ac5746aa7a03b3014902dc2db5273
    ... blah blah blah ...

    % ls nodejs*.deb
    nodejs-htmlparser-1.7.3-1_all.deb  nodejs-jsdom-0.1.22-1_all.deb

    % dpkg -c nodejs-jsdom-0.1.22-1_all.deb


