#
# To build this Docker image: docker build -t fpm .
#
# To run this Docker container interactively: docker run --rm -it fpm
#

FROM alpine:3.9

ENV COMMON_PKGS \
        binutils \
        git \
        libffi \
        ruby \
        ruby-etc \
        tar

ENV BUILD_DEPS \
        gcc \
        libc-dev \
        ruby-dev \
        libffi-dev \
        make

COPY . /workdir

RUN set -xe \
 && apk add -q --clean-protected --no-cache --update --virtual .image-libs ${COMMON_PKGS} \
 && apk add -q --clean-protected --no-cache --update --virtual .build-deps ${BUILD_DEPS} \
 && cd /workdir \
 && gem build fpm.gemspec \
 && gem install --no-ri --no-rdoc fpm \
 && apk del .build-deps

ENTRYPOINT [ "/usr/bin/fpm" ]

CMD ["-h"]
