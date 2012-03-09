# Effing Package Management.

## Preface

Package maintainers work hard and take a lot of shit. You can't please everyone. So, if you're a maintainer: Thanks for maintaining packages!

## What is fpm?

It helps you build packages quickly (Packages like RPM and DEB formats).

Here is a presentation I gave on fpm at BayLISA: <http://goo.gl/sWs3Z> (I
included speaker notes you can read, too)

At BayLISA in April 2011, I gave a talk about fpm. At the end, I asked "What
can I package for you?"

Someone asked for memcached.

Google for 'memcached', download the source, unpack, ./configure, make, make
install, fpm, deploy.

In 60 seconds, starting from nothing, I had both an RPM and a .DEB of memcached
ready to deploy, and I didn't need to know how to use rpmbuild, rpm specfiles,
dh_make, debian control files, etc.

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
* python modules (autodownload for you)
* directories
* rpm
* node packages (npm)

Targets:

* deb
* rpm
* solaris

## Need Help or Want to Contribute?

All contributions are welcome: ideas, patches, documentation, bug reports,
complaints, and even something you drew up on a napkin.

It is more important to me that you are able to contribute and get help if you
need it..

That said, some basic guidelines, which you are free to ignore :)

* Have a problem you want fpm to solve for you? You can email the
  [mailing list](http://groups.google.com/group/fpm-users), or
  join the IRC channel #fpm on irc.freenode.org, or email me personally
  (jls@semicomplete.com)
* Have an idea or a feature request? File a ticket on
  [github](https://github.com/jordansissel/fpm/issues), or email the
  [mailing list](http://groups.google.com/group/fpm-users), or email
  me personally (jls@semicomplete.com) if that is more comfortable.
* If you think you found a bug, it probably is a bug. File it on
  [jira](https://github.com/jordansissel/fpm/issues) or send details to
  the [mailing list](http://groups.google.com/group/fpm-users).
* If you want to send patches, best way is to fork this repo and send me a pull
  request. If you don't know git, I also accept diff(1) formatted patches -
  whatever is most comfortable for you.
* Want to lurk about and see what others are doing? IRC (#fpm on
  irc.freenode.org) is a good place for this as is the 
  [mailing list](http://groups.google.com/group/fpm-users)

## Other Documentation

[See the wiki for more docs](https://github.com/jordansissel/fpm/wiki)

