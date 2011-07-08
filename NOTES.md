
# Debian notes

## C libraries

Linux seems to require 'ldconfig' runs after shared libraries are installe. I
haven't bothered digging into why, but many debian C library packages run
ldconfig as a postinstall step.

I'd like to avoid postinstall actions, so this needs research to see if this is
possible.

## Ruby

rubygems on Debian/Ubuntu is not very recent in most cases, and some gems have
a requirement of rubygems >= a version you have available.

Further, debian blocks 'gem update --system' which you can get around by doing:

    % gem install rubygems-update
    % ruby /var/lib/gems/1.8/gems/rubygems-update-1.3.1/bin/update_rubygems

I recommend packaging 'rubygems-update' (fpm -s gem -t deb rubygems-update) and
possibly running the update_rubygems as a postinstall, even though I don't like
postinstalls. I haven't looked yet to see what is required to mimic (if
possible) the actions of that script simply in a tarball.

## Python

http://www.debian.org/doc/packaging-manuals/python-policy/ap-packaging_tools.html

Debian python packages all rely on some form of python-central or
python-support (different tools that do similar/same things? I don't know)

As I found, disabling postinst scripts in Debian causes Python to stop working.
The postinst scripts generally look like this:

    if which update-python-modules >/dev/null 2>&1; then
      update-python-modules  SOMEPACKAGENAME.public
    fi

I don't believe in postinst scripts, and I also feel like requiring a
postinstall step to make a python module work is quite silly - though I'm sure
(I hope) Debian had good reason.

So, I'm going to try working on a howto for recommended ways to build python
packages with fpm in debian. It will likely require a one-time addition to
site.py (/usr/lib/python2.6/site.py) or some other PYTHONPATH hackery, though
I don't know just yet.

It will also require special setup.py invocations as Debian has patched distutils to
install python packages, by default, to a place that requires again the
python-central/support tools to run to make them work.
