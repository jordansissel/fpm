FROM ubuntu:18.04 as base

# Runtime deps. Build deps go in the build or test containers
RUN apt-get update \
	&& apt-get -y dist-upgrade \
	&& apt-get install --no-install-recommends -y \
	ruby rubygems rubygems-integration \
	bsdtar \
	cpio \
	debsigs \
	pacman \
	perl \
	python3-pip \
	python3-setuptools \
	rpm  \
	squashfs-tools \
	xz-utils \
	zip \
	&& rm -rf /var/lib/apt/lists/* \
	&& apt-get clean


# Run tests. This is a bit broken now.
# See https://github.com/jordansissel/fpm/issues/1682
FROM base AS fpm-test
WORKDIR /src
RUN apt-get update && apt-get install --no-install-recommends -y gcc make ruby-dev libc-dev lintian git
RUN git clone https://github.com/jordansissel/fpm /src
#COPY . /src
RUN gem install --no-ri --no-rdoc bundler
RUN cd /src && bundle install
RUN cd /src && rspec
ENTRYPOINT rspec

# build container, install build deps here, so we can omit them from
# our release package
FROM base AS build
RUN apt-get update
RUN apt-get install --no-install-recommends -y \
	gcc make ruby-dev libc-dev
ENV GEM_PATH /fpm
ENV PATH "/fpm/bin:${PATH}"
RUN gem install --no-ri --no-rdoc --install-dir=/fpm fpm
RUN gem clean

FROM base as release
COPY --from=build /fpm /fpm
ENV GEM_PATH /fpm
ENV PATH "/fpm/bin:${PATH}"
ENTRYPOINT /fpm/bin/fpm
