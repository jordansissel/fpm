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

(This is not to say that you can't create packages with FPM that obey Debian or
RedHat policies, you can and should if that is what you desire)

The goal of FPM is to be able to easily build platform-native packages.

* Creating packages easily (deb, rpm, etc)
* Tweaking existing packages (removing files, changing metadata/dependencies)
* Stripping pre/post/maintainer scripts from packages

## Get with the download

You can install fpm with gem:

    gem install fpm

It ships with 'fpm' and 'fpm-npm' tools.

## Things that are in the works or should work:

Sources:

* gem (even autodownloaded for you)
* directories
* rpm
* node packages (npm)

Targets:

* deb
* rpm

## Other Documentation

[See the wiki for more docs](https://github.com/jordansissel/fpm/wiki)

