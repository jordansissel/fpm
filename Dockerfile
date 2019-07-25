#
# To build this Docker image: docker build -t fpm .
#
# To run this Docker container interactively: docker run -it fpm
#
FROM alpine:3.10

RUN apk add --no-cache \
        ruby \
        ruby-dev \
        gcc \
        libffi-dev \
        make \
        libc-dev \
        rpm \
        tar \
    && gem install --no-ri --no-rdoc fpm
