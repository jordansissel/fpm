# syntax=docker/dockerfile:1

# Are we running against the minimal container, or the everything
# container? Minimal is mostly the compiled package tools. Everything
# pulls in scripting langauges.
ARG BASE_ENV=everything

# Are we running tests, or a release? Tests build and run against the
# CWD, where release will use the downloaded gem.
ARG TARGET=test

# Container to throw an error if called with a bare `docker build .`
FROM ubuntu:20.04 as error
RUN <<EOF
  printf '\n\n\n%s\n\n\n' "Hey! Use buildkit. See the Makefile or docs"
  false
EOF

# Base container is used for various release and test things
FROM ubuntu:20.04 as minimal-base
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC
# Runtime deps. Build deps go in the build or test containers
# hadolint ignore=DL3009
RUN <<EOF
  apt-get update
  apt-get install --no-install-recommends --no-install-suggests -y \
    'ruby=*' \
    'ruby-dev=*' \
    'libarchive-tools=*' \
    'cpio=*' \
    'debsigs=*' \
    'pacman=*' \
    'rpm=*'  \
    'squashfs-tools=*' \
    'xz-utils=*' \
    'zip=*' \
    'gcc=*' \
    'libc6-dev=*' \
    'make=*' \
    'lintian=*' \
    'git=*'
    useradd -ms /bin/bash fpm
EOF

# everything container includes all the scripting languages. These
# greatly embiggen the underlying docker container, so they're
# conditionalized.
FROM minimal-base as everything-base
RUN <<EOF
  apt-get install --no-install-recommends --no-install-suggests -y \
    'cpanminus=*' \
    'npm=*' \
    'perl=*' \
    'python3-pip=*'
  pip3 --no-cache-dir install 'setuptools>=45' 'wheel>=0.34' 'virtualenv>=20' 'virtualenv-tools3>=2'
  update-alternatives --install /usr/bin/python python /usr/bin/python3 10
EOF

# hadolint ignore=DL3006
FROM ${BASE_ENV}-base as base
RUN <<EOF
  rm -rf /var/lib/apt/lists/*
  apt-get clean
EOF

# Run tests against the current working directory. This is a bit
# orthogonal to the container release process, but it has a lot of
# same dependancies, so we reuse it. This uses COPY to allow rspect to
# initall the gems, but runtime usage expects you to mount a volume
# into /src
FROM base AS test
# installing ffi here is a bit of an optimization for how COPY and layer reuse works
RUN gem install --no-document ffi:*
USER fpm
WORKDIR /origsrc
ENV HOME=/origsrc
ENV BUNDLE_PATH=/origsrc/.bundle
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN <<EOF
  # Install a specific version of bundler
  install -d -o fpm /origsrc
  gem install -v "$(grep -A1 '^BUNDLED WITH' Gemfile.lock | tail -1)" bundler:*
  bundle install
EOF

CMD ["bundle", "exec", "rspec"]

# build a container from a released gem. install build deps here, so
# we can omit them from the final release package
FROM base AS build
ENV GEM_PATH=/fpm
ENV PATH="/fpm/bin:${PATH}"
# hadolint ignore=DL3028
RUN gem install --no-document --install-dir=/fpm fpm

FROM base as release
COPY --from=build /fpm /fpm
ENV GEM_PATH=/fpm
ENV PATH="/fpm/bin:${PATH}"
USER fpm
WORKDIR /src
ENTRYPOINT ["/fpm/bin/fpm"]

# This target is to help docker buildkit in resolving things.
# hadolint ignore=DL3006
FROM ${TARGET}
