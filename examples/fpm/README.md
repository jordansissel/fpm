Notes:

    You should have write permission on /opt directory

Dependencies:

    $ sudo apt-get install build-essential bison openssl libreadline6 libreadline6-dev zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0 libxml2-dev libxslt-dev autoconf libc6-dev

Usage:

    $ make package

Should make the package. Try installing:

    $ sudo dpkg -i fpm-0.2.30.x86.deb

Now try it:

    $ /opt/fpm/bin/fpm --help
