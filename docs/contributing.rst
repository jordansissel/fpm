Contributing/Issues
===================

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms. See the `Code of Conduct`_ for details.

.. _Code of Conduct: https://github.com/jordansissel/fpm/blob/master/CODE_OF_CONDUCT.md

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin :)

It is more important that you are able to contribute and get help if you need it than it is how you contribute or get help.

That said, some points to get started:

* Have a problem you want FPM to solve for you? You can email the `mailing list`_, or join the IRC channel #fpm on irc.freenode.org, or email me personally (jls@semicomplete.com)
* Have an idea or a feature request? File a ticket on `github`_, or email the `mailing list`_, or email me personally (jls@semicomplete.com) if that is more comfortable.
* If you think you found a bug, it probably is a bug. File it on `github`_ or send details to the `mailing list`_.
* If you want to send patches, best way is to fork this repo and send me a pull request. If you don't know git, I also accept diff(1) formatted patches - whatever is most comfortable for you.
* Want to lurk about and see what others are doing? IRC (#fpm on irc.freenode.org) is a good place for this as is the `mailing list`_.

.. _mailing list: https://groups.google.com/group/fpm-users
.. _github: https://github.com/jordansissel/fpm

Contributing changes by forking from GitHub
-------------------------------------------

First, create a GitHub account if you do not already have one. Log in to
GitHub and go to [the main FPM GitHub page](https://github.com/jordansissel/fpm).

At the top right, click on the button labeled "Fork".  This will put a forked
copy of the main FPM repo into your account.  Next, clone your account's GitHub
repo of FPM. For example:

    $ git clone git@github.com:yourusername/fpm.git

Development Environment
-----------------------

If you don't already have the bundler gem installed, install it now:

    $ gem install bundler

Now change to the root of the FPM repo and run:

    $ bundle install

This will install all of the dependencies required for running FPM from source.
Most importantly, you should see the following output from the bundle command
when it lists the FPM gem:

    ...
    Using json (1.8.1)
    Using fpm (0.4.42) from source at .
    Using hitimes (1.2.1)
    ...

If your system doesn't have `bsdtar` by default, make sure to install it or some
tests will fail:

    apt-get install bsdtar || apt install libarchive-tools
    
    yum install bsdtar


You also need these tools:

    apt-get install lintian cpanminus

Next, run make in root of the FPM repo. If there are any problems (such as
missing dependencies) you should receive an error

At this point, the FPM command should run directly from the code in your cloned
repo.  Now simply make whatever changes you want, commit the code, and push
your commit back to master.

If you think your changes are ready to be merged back to the main FPM repo, you
can generate a pull request on the GitHub website for your repo and send it in
for review.

Problems running bundle install?
--------------------------------

If you are installing on Mac OS 10.9 (Mavericks) you will need to make sure that 
you have the standalone command line tools separate from Xcode:

    $ xcode-select --install

Finally, click the install button on the prompt that appears.

Editing Documentation
---------------------

If you want to edit the documentation, here's a quick guide to getting started:

* Install `docker`_.
* All documentation is located in the `docs` folder. ``cd`` into the docs folder and run the following command once::

	make docker-prep

* Once that is done, run ``make build`` whenever you want to build the site. It will generate the html in the `_build/html` directory.
* You can use any tool like `serve _build/html` (npm package) or ``python -m http.server -d _build/html 5000`` to serve the static html on your machine (http://localhost:5000).

.. _docker: https://docs.docker.com/engine/install/

Now you can simply make whatever changes you want, commit the code, and push your commit back to master.

If you think your changes are ready to be merged back to the main FPM repo, you can generate a pull request on the GitHub website for your repo and send it in for review.
