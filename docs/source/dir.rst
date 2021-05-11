`dir` - Directories
===================

Synopsis::

  fpm -s dir [other flags] path1 [path2 ...]

The 'dir' source will package up one or more directories for you.

Path mapping
------------

.. note::
  Path mapping was added in fpm version 0.4.40

Some times you want to take a path and copy it into a package but under a different location.  fpm can use the `=` directive to mark that::

  fpm [...] -s dir ./example/foo=/usr/bin/ 

This will put the file `foo` in the /usr/bin directory inside the package.

A simple example of this can be shown with redis. Redis has a config file
(redis.conf) and an executable (redis-server). Let's put the executable in
/usr/bin and the config file in /etc/redis::

  % ls src/redis-server redis.conf
  src/redis-server
  redis.conf

  # install src/redis-server into /usr/bin/
  # install redis.conf into /etc/redis/
  % fpm -s dir -t deb -n redis --config-files /etc/redis/redis.conf -v 2.6.10 \
    src/redis-server=/usr/bin/ \
    redis.conf=/etc/redis/
  Created deb package {:path=>"redis_2.6.10_amd64.deb"}

  % dpkg -c redis_2.6.10_amd64.deb
  drwx------ jls/jls           0 2013-07-11 23:49 ./
  drwxrwxr-x jls/jls           0 2013-07-11 23:49 ./etc/
  drwxrwxr-x jls/jls           0 2013-07-11 23:49 ./etc/redis/
  -rw-rw-r-- jls/jls       24475 2013-02-11 04:24 ./etc/redis/redis.conf
  drwxrwxr-x jls/jls           0 2013-07-11 23:49 ./usr/
  drwxrwxr-x jls/jls           0 2013-07-11 23:49 ./usr/bin/
  -rwxrwxr-x jls/jls     3566152 2013-02-14 11:19 ./usr/bin/redis-server

  # Did the conffiles setting work? Yep!
  % dpkg-deb -e redis_2.6.10_amd64.deb  .
  % cat conffiles
  /etc/redis/redis.conf

Voila!

