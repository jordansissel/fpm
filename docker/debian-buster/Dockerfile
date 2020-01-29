FROM debian:buster as fpm

# Documented dependencies
RUN apt-get update && apt-get -y dist-upgrade
RUN apt-get install -y ruby ruby-dev rubygems build-essential

# Discovered dependancies
RUN apt-get install -y \
	bsdtar rpm lintian python3-setuptools python3-pip \
	squashfs-tools perl cpio


# New second stage container to run tests in
FROM fpm AS fpm-test
WORKDIR /fpm
RUN apt-get install -y git && \
	git clone https://github.com/jordansissel/fpm /fpm

RUN gem install --no-ri --no-rdoc bundler
RUN cd /fpm && bundle install
ENTRYPOINT rspec
