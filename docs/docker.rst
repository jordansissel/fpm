FPM and Docker
==============

Because fpm depends on so many underlying system tools, docker can
alleviate the need to install them locally.

An end user may use a docker container in lieu of installing
locally. And a developer can use docker to run the test suite.


Running FPM inside docker
-------------------------

First, build a container will all the dependencies::

   make docker-release-everything

Now, run it as you would the fpm command. Note that you will have to
mount your source directly into the docker volume::

   docker run -v $(pwd):/src fpm --help

As a full example::

   mkdir /tmp/fpm-test
   mkdir /tmp/fpm-test/files
   touch /tmp/fpm-test/files/one
   touch /tmp/fpm-test/files/two

   docker run -v /tmp/fpm-test/files:/src -v /tmp/fpm-test:/out fpm -s dir -t tar -n example -p /out/out.tar .

   tar tf /tmp/fpm-test/out.tar

Depending on your needs, you will have to adjust the volume mounts and
relative paths to fit your particular situation.

Running rpsec inside docker
---------------------------

The Makefile provides some targets for testing. They will build a
docker container with the dependencies, and then invoked `rspec`
inside it. The makefile uses a sentinel file to indicate that the
docker image has been build, and can be reused.

   make docker-test-everything



How does this work
------------------

The Dockerfile makes heavy use of multistage
builds. This allows the various output containers to build on the same
earlier stages.

There are two ``base`` images. A ``minimal`` image, which contains
compiled dependencies and ruby. And an ``everything`` image which brings
in scripting systems like ``python`` and ``perl``. These are split to
allow a smaller ``minimal`` image in cases where building scripting
language packages are not needed.

The Dockerfile the argument ``BASE_ENV`` to specify what base image to
use. This can be set to either ``minimal`` or ``everything``. If
unspecified, it defaults to ``everything``

We want to use the same set of base images for both the ``rspec``
testing, as well as the run time containerization. We do this by using
the ``TARGET`` argument to select which container to build.

The makefile encodes this logic with two pattern rules.
