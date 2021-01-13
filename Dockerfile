#
# To build this Docker image: docker build -t fpm .
#
# To run this Docker container interactively: docker run -it fpm
#
FROM alpine:3.12

RUN apk add --no-cache \
        ruby \
        ruby-dev \
        ruby-etc \
        gcc \
        libffi-dev \
        make \
        libc-dev \
        rpm \
    && gem install --no-document fpm
