`gem` - RubyGems
================

Simplest invocation
-------------------

Here's a command that will fetch the latest `json` gem and convert it to a .deb package::

    % cd /tmp
    % fpm -s gem -t deb json
    ...
    Created /tmp/rubygem-json-1.4.6-1.amd64.deb

This will download the latest 'json' rubygem from rubygems.org and convert it
to a .deb. It will create a package named 'rubygem-json-VERSION_ARCH.deb' with
appropriate version/arch in place.

Check the package::

    % dpkg --info rubygem-json-1.4.6-1.amd64.deb 
     new debian package, version 2.0.
     size 1004040 bytes: control archive= 335 bytes.
         275 bytes,    10 lines      control              
           5 bytes,     1 lines      md5sums              
     Package: rubygem-json
     Version: 1.4.6-1
     Architecture: amd64
     Maintainer: Florian Frank
     Standards-Version: 3.9.1
     Section: Languages/Development/Ruby 
     Priority: extra
     Homepage: http://flori.github.com/json
     Description: JSON Implementation for Ruby
       JSON Implementation for Ruby

From the above, you can see that fpm automatically picked the package name,
version, maintainer, section, homepage, and description all from the rubygem
itself. Nothing for you to worry about :)

Specifying a version
--------------------

You can ask for a specific version with '-v <VERSION>'. It will also handle
dependencies. How about an older gem like rails 2.2.2::

    % fpm -s gem -t deb -v 2.2.2 rails
    Trying to download rails (version=2.2.2)
    ...
    Created .../rubygem-rails-2.2.2-1.amd64.deb

Now observe the package created:

    % dpkg --info ./rubygem-rails-2.2.2-1.amd64.deb
     new debian package, version 2.0.
     size 2452008 bytes: control archive= 445 bytes.
         575 bytes,    11 lines      control              
           6 bytes,     1 lines      md5sums              
     Package: rubygem-rails
     Version: 2.2.2-1
     Architecture: amd64
     Maintainer: David Heinemeier Hansson
     Depends: rubygem-rake (>= 0.8.3), rubygem-activesupport (= 2.2.2),
       rubygem-activerecord (= 2.2.2), rubygem-actionpack (= 2.2.2),
       rubygem-actionmailer (= 2.2.2), rubygem-activeresource (= 2.2.2)
     Standards-Version: 3.9.1
     Section: Languages/Development/Ruby 
     Priority: extra
     Homepage: http://www.rubyonrails.org
     Description: Web-application framework with template engine, control-flow layer, and ORM.
       Web-application framework with template engine, control-flow layer, and ORM.

Noticei how the `Depends` entry for this debian package lists all the dependencies that `rails` has?

Let's see what the package installs::

    % dpkg -c ./rubygem-rails-2.2.2-1.amd64.deb
    ...
    drwxr-xr-x root/root         0 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/
    drwxr-xr-x root/root         0 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/
    -rw-r--r-- root/root      3639 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/source_annotation_extractor.rb
    -rw-r--r-- root/root       198 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/performance_test_help.rb
    drwxr-xr-x root/root         0 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/tasks/
    -rw-r--r-- root/root       204 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/tasks/log.rake
    -rw-r--r-- root/root      2695 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/tasks/gems.rake
    -rw-r--r-- root/root      4858 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/tasks/testing.rake
    -rw-r--r-- root/root     17727 2011-01-20 17:00 ./usr/lib/ruby/gems/1.8/gems/rails-2.2.2/lib/tasks/databases.rake

Packaging individual dependencies
---------------------------------

A frequently-asked question is how to get a rubygem and all its dependencies
converted. Let's take a look.

First we'll have to download the gem and its deps. The easiest way to do this
is to stage the installation in a temporary directory, like this::

    % mkdir /tmp/gems
    % gem install --no-ri --no-rdoc --install-dir /tmp/gems cucumber
    <output trimmed>

    Successfully installed json-1.4.6
    Successfully installed gherkin-2.3.3
    Successfully installed term-ansicolor-1.0.5
    Successfully installed builder-3.0.0
    Successfully installed diff-lcs-1.1.2
    Successfully installed cucumber-0.10.0
    6 gems installed

Now you've got everything cucumber requires to run (just as a normal 'gem
install' would.)

`gem` saves gems to the cache directory in the gem install dir, so check it out::

     % ls /tmp/gems/cache 
     builder-3.0.0.gem    diff-lcs-1.1.2.gem  json-1.4.6.gem
     cucumber-0.10.0.gem  gherkin-2.3.3.gem   term-ansicolor-1.0.5.gem

(by the way, under normal installation situations, gem would keep the cache in
a location like /usr/lib/ruby/gems/1.8/cache, see 'gem env | grep INSTALL')

Let's convert all these gems to debs (output trimmed for sanity)::

    % find /tmp/gems/cache -name '*.gem' | xargs -rn1 fpm -d ruby -d rubygems --prefix $(gem environment gemdir) -s gem -t deb
    ...
    Created /tmp/gems/rubygem-json-1.4.6-1.amd64.deb
    ...
    Created /tmp/gems/rubygem-builder-3.0.0-1.amd64.deb
    ...
    Created /tmp/gems/rubygem-gherkin-2.3.3-1.amd64.deb
    ...
    Created /tmp/gems/rubygem-diff-lcs-1.1.2-1.amd64.deb
    ...
    Created /tmp/gems/rubygem-term-ansicolor-1.0.5-1.amd64.deb
    ...
    Created /tmp/gems/rubygem-cucumber-0.10.0-1.amd64.deb

    % ls *.deb
    rubygem-builder-3.0.0-1.amd64.deb    rubygem-gherkin-2.3.3-1.amd64.deb
    rubygem-cucumber-0.10.0-1.amd64.deb  rubygem-json-1.4.6-1.amd64.deb
    rubygem-diff-lcs-1.1.2-1.amd64.deb   rubygem-term-ansicolor-1.0.5-1.amd64.deb

Nice, eh? Now, let's show what happens after these packages are installed::

    # Show it's not install yet:
    % gem list cucumber

    *** LOCAL GEMS ***

    
    # Now install the .deb packages:
    % sudo dpkg -i rubygem-builder-3.0.0-1.amd64.deb \
      rubygem-cucumber-0.10.0-1.amd64.deb rubygem-diff-lcs-1.1.2-1.amd64.deb \
      rubygem-gherkin-2.3.3-1.amd64.deb rubygem-json-1.4.6-1.amd64.deb \
      rubygem-term-ansicolor-1.0.5-1.amd64.deb
    ...
    Setting up rubygem-builder (3.0.0-1) ...
    Setting up rubygem-diff-lcs (1.1.2-1) ...
    Setting up rubygem-json (1.4.6-1) ...
    Setting up rubygem-term-ansicolor (1.0.5-1) ...
    Setting up rubygem-gherkin (2.3.3-1) ...
    Setting up rubygem-cucumber (0.10.0-1) ...

    # Is it installed?
    % gem list cucumber

    *** LOCAL GEMS ***

    cucumber (0.10.0)

    # Does it work?
    % dpkg -L rubygem-cucumber | grep bin
    /usr/lib/ruby/gems/1.8/gems/cucumber-0.10.0/bin
    /usr/lib/ruby/gems/1.8/gems/cucumber-0.10.0/bin/cucumber
    /usr/lib/ruby/gems/1.8/bin
    /usr/lib/ruby/gems/1.8/bin/cucumber

    % /usr/lib/ruby/gems/1.8/bin/cucumber --help
    Usage: cucumber [options] [ [FILE|DIR|URL][:LINE[:LINE]*] ]+
    ...


You can put these .deb files in your apt repo (assuming you have a local apt
repo, right?) and easily install them with 'apt-get' like: 'apt-get install
rubygem-cucumber' and expect dependencies to work nicely.

Deterministic output
--------------------

If convert a gem to a deb twice, you'll get different output even though the inputs didn't change:

    % fpm -s gem -t deb json
    % mkdir run1; mv *.deb run1
    % sleep 1
    % fpm -s gem -t deb json
    % mkdir run2; mv *.deb run2
    % cmp run1/*.deb run2/*.deb
    run1/rubygem-json_2.1.0_amd64.deb run2/rubygem-json_2.1.0_amd64.deb differ: byte 124, line 4

This can be a pain if you're uploading packages to an apt repository
which refuses reuploads that differ in content, or if you're trying
to verify that packages have not been infected.
There are several sources of nondeterminism; use 'diffoscope run1/*.deb run2/*.deb' if you
want the gory details.  See http://reproducible-builds.org for the whole story.

To remove nondeterminism due to differing timestamps,
use the option --source-date-epoch-from-changelog; that will use the timestamp from
the gem's changelog.

In case the gem doesn't have a standard changelog (and most don't, alas),
use --source-date-epoch-default to set a default integer Unix timestamp.
(This will also be read from the environment variable SOURCE_DATE_EPOCH if set.)

Gems that include native extensions may have nondeterministic output
because of how the extensions get built (at least until fpm and
compilers finish implementing the reproducible-builds.org
recommendations).  If this happens, use the option --gem-stagingdir=/tmp/foo.

For instance, picking the timestamp 1234 seconds after the Unix epoch:

    % fpm -s gem -t deb --source-date-epoch-default=1234 --gem-stagingdir=/tmp/foo json
    % mkdir run1; mv *.deb run1
    % sleep 1
    % fpm -s gem -t deb --source-date-epoch-default=1234 --gem-stagingdir=/tmp/foo json
    % mkdir run2; mv *.deb run2
    % cmp run1/*.deb run2/*.deb
    % dpkg-deb -c run1/*.deb
    ...
    -rw-rw-r-- 0/0           17572 1969-12-31 16:20 ./var/lib/gems/2.3.0/gems/json-2.1.0/CHANGES.md
    % date --date @1234
    Wed Dec 31 16:20:34 PST 1969

If after using those three options, the files are still different,
you may have found a bug; we might not have plugged all the sources
of nondeterminism yet.  As of this writing, these options are only
implemented for reading gems and writing debs, and only verified
to produce identical output when run twice on the same Linux system.
