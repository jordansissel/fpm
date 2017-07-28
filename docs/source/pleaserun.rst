`pleaserun` - Please, run!
===================

Synopsis::

  fpm -s pleaserun [other flags] program [args...]

The `pleaserun` source uses the pleaserun_ project to help you build a package
that installs a service.

.. _pleaserun: http://github.com/jordansissel/pleaserun

`pleaserun` supports the following service managers:

* sysv, /etc/init.d/whatever
* upstart
* systemd
* runit
* launchd (OS X)

Automatic Platform Detection
============================

Targeting multiple platforms with a single package is hard. What init system is used? Can you predict?

fpm+pleaserun can detect this at installation-time!

One Package for All Platforms
-----------------------------

The following is an example which creates an rpm that makes `redis` service
available::

  fpm -s pleaserun -t rpm -n redis-service /usr/bin/redis-server

The output looks like this::

  Created package {:path=>"redis-service-1.0-1.x86_64.rpm"}

.. note::
  You do not need to tell `fpm` which service platform you are targeting! Watch below :)

Let's see what happens when I install this on Fedora 25 (which uses systemd)::

  % sudo rpm -i redis-service-1.0-1.x86_64.rpm
  Platform systemd (default) detected. Installing service.
  To start this service, use: systemctl start redis-server

And checking on our service::

  % systemctl status redis-server
  ● redis-server.service - redis-server
     Loaded: loaded (/etc/systemd/system/redis-server.service; disabled; vendor pr
     Active: inactive (dead)

(It is inactive and disabled because fpm does not start it by default)

As you can see in the above example, `fpm` added an after-install script which
detects the service manager during installation. In this case, `systemd` was
detected.

The above example shows installing on Fedora 25, which uses systemd. You can use this same rpm package on CentOS 6, which uses upstart, and it will still work::

  % sudo rpm -i redis-service-1.0-1.x86_64.rpm
  Platform upstart (0.6.5) detected. Installing service.
  To start this service, use: initctl start redis-server

And checking on our service::

  % initctl status redis-server
  redis-server stop/waiting

Hurray! We now have a single rpm that installs this `redis-service` service on
most systems.
