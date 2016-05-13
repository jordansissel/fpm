# Effing Package Management

[![Build Status](https://travis-ci.org/jordansissel/fpm.svg?branch=master)](https://travis-ci.org/jordansissel/fpm)

## Preface

Package maintainers work hard and take a lot of shit. You can't please
everyone. So, if you're a maintainer: Thanks for maintaining packages!

## What is fpm?

It helps you build packages quickly and easily (Packages like RPM and DEB
formats).

FUNDAMENTAL PRINCIPLE: IF FPM IS NOT HELPING YOU MAKE PACKAGES EASILY, THEN
THERE IS A BUG IN FPM.

Here is a presentation I gave on fpm at BayLISA: <http://goo.gl/sWs3Z> (I
included speaker notes you can read, too)

At BayLISA in April 2011, I gave a talk about fpm. At the end, I asked "What
can I package for you?"

Someone asked for memcached.

Google for 'memcached', download the source, unpack, ./configure, make, make
install, fpm, deploy.

In 60 seconds, starting from nothing, I had both an RPM and a .DEB of memcached
ready to deploy, and I didn't need to know how to use rpmbuild, rpm specfiles,
dh\_make, debian control files, etc.

## Backstory

Sometimes packaging is done wrong (because you can't do it right for all
situations), but small tweaks can fix it.

And sometimes, there isn't a package available for the tool you need.

And sometimes if you ask "How do I get python 3 on CentOS 5?" some unhelpful
trolls will tell you to "Use another distro"

Further, a job switches have me flipping between Ubuntu and CentOS. These use
two totally different package systems with completely different packaging
policies and support tools. Learning both was painful and confusing. I want to
save myself (and you) that pain in the future.

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

## System packages

Many Linux distros do not ship ruby C headers or a compiler by default, and
you'll need that to install fpm.

```
# deb based distributions:
    apt-get install ruby-dev gcc make
# rpm ones:
    yum install ruby-devel gcc make
```

Additional packages will be required depending on the source and target package
types (rpmbuild for rpm, etc.). FPM will show the commands that are required
which you must map to your distribution's package names.

## Get with the download

You can install fpm with gem:

    gem install fpm
    
(On OS X, you may also need gnutar: `brew install gnu-tar`.)

Building a package might look something like this:

    fpm -s <source type> -t <target type> [list of sources]...

"Source type" is what your package is coming from; a directory (dir), a rubygem
(gem), an rpm (rpm), a python package (python), a php pear module (pear), etc.

"Target type" is what your output package form should be. Most common are "rpm"
and "deb" but others exist (solaris, etc)

You have two options for learning to run FPM:

1. If you're impatient, just scan through `fpm --help`; you'll need various
   options, and they're reasonably straightforward. Impatient learning is
   totally welcome, and if you run into issues, ask questions in #fpm on
   freenode irc or on fpm-users@googlegroups.com!
1. [The wiki](https://github.com/jordansissel/fpm/wiki) has explanations and
   examples. If you run into problems, I welcome you to ask questions in #fpm
   on freenode irc or on fpm-users@googlegroups.com!

## Things that are in the works or should work:

Sources:

* gem (even autodownloaded for you)
* python modules (autodownload for you)
* pear (also downloads for you)
* directories
* tar(.gz) archives
* rpm
* deb
* node packages (npm)
* pacman (ArchLinux) packages

Targets:

* deb
* rpm
* solaris
* tar
* directories
* Mac OS X `.pkg` files (`osxpkg`)
* pacman (ArchLinux) packages

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
  [GitHub](https://github.com/jordansissel/fpm/issues), or email the
  [mailing list](http://groups.google.com/group/fpm-users), or email
  me personally (jls@semicomplete.com) if that is more comfortable.
* If you think you found a bug, it probably is a bug. File it on
  [GitHub](https://github.com/jordansissel/fpm/issues) or send details to
  the [mailing list](http://groups.google.com/group/fpm-users).
* If you want to send patches, best way is to fork this repo and send me a pull
  request. If you don't know git, I also accept diff(1) formatted patches -
  whatever is most comfortable for you.
* Want to lurk about and see what others are doing? IRC (#fpm on
  irc.freenode.org) is a good place for this as is the 
  [mailing list](http://groups.google.com/group/fpm-users)

### Contributing by forking from GitHub

Please note that this project is released with a Contributor Code of Conduct.
By participating in this project you agree to abide by its terms. See
the [CODE\_OF\_CONDUCT.md](CODE_OF_CONDUCT.md).

First, create a GitHub account if you do not already have one.  Log in to
GitHub and go to [the main fpm GitHub page](https://github.com/jordansissel/fpm).

At the top right, click on the button labeled "Fork".  This will put a forked
copy of the main fpm repo into your account.  Next, clone your account's GitHub
repo of fpm.  For example:

    $ git clone git@github.com:yourusername/fpm.git

If you don't already have the bundler gem installed, install it now:

    $ gem install bundler

Now change to the root of the fpm repo and run:

    $ bundle install

This will install all of the dependencies required for running fpm from source.
Most importantly, you should see the following output from the bundle command
when it lists the fpm gem:

    ...
    Using json (1.8.1)
    Using fpm (0.4.42) from source at .
    Using hitimes (1.2.1)
    ...

If your system doesn't have `bsdtar` by default, make sure to install it or some
tests will fail:

    apt-get install bsdtar
    
    yum install bsdtar

Next, run make in root of the fpm repo.  If there are any problems (such as
missing dependencies) you should receive an error

At this point, the fpm command should run directly from the code in your cloned
repo.  Now simply make whatever changes you want, commit the code, and push
your commit back to master.

If you think your changes are ready to be merged back to the main fpm repo, you
can generate a pull request on the GitHub website for your repo and send it in
for review.

##Problems running bundle install?

If you are installing on Mac OS 10.9 (Mavericks) you will need to make sure that 
you have the standalone command line tools separate from Xcode:

    $ xcode-select --install

Finally, click the install button on the prompt that appears.



## More Documentation

[See the wiki for more docs](https://github.com/jordansissel/fpm/wiki)

