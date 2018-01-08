
#
# To build this Docker image: docker build -t fpm .
#
# To run this Docker container interactively: docker run -it fpm
#
FROM alpine:latest

RUN apk add --update \
        ruby \
        ruby-dev gcc \
        libffi-dev \
        make \
        libc-dev \
        rpm && \
        gem install --no-ri --no-rdoc fpm


