#
# To build this Docker image: docker build -t fpm .
#
# To run this Docker container interactively: docker run --rm -it fpm
#
FROM alpine:3.9

ENV COMMON_PKGS \
        ruby \
        libffi \
        tar \
        binutils

ENV BUILD_DEBS \
        gcc \
        libc-dev \
        ruby-dev \
        libffi-dev \
        make

RUN set -xe \
 && apk add -q --clean-protected --no-cache --update --virtual .image-libs ${COMMON_PKGS} \
 && apk add -q --clean-protected --no-cache --update --virtual .build-deps ${BUILD_DEBS} \
 && update-ca-certificates \
 && gem install --no-ri --no-rdoc fpm \
 && apk del .build-deps \
 && rm -Rf /usr/share/man \
 && rm -Rf /tmp/*         \
 && rm -Rf /var/cache/apk/*

ENTRYPOINT [ "/usr/bin/fpm" ]

CMD ["-h"]
