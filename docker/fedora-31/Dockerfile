FROM fedora:31 as fpm

# Documented dependencies
RUN dnf install -y ruby-devel gcc make rpm-build libffi-devel

# Discovered dependancies
RUN dnf install -y squashfs-tools bsdtar

# New second stage container to run tests in
FROM fpm AS fpm-test
WORKDIR /fpm

RUN dnf install -y git && \
	git clone https://github.com/jordansissel/fpm /fpm

RUN gem install bundler
RUN cd /fpm && bundle install
ENTRYPOINT rspec
