# This Dockerfile produces a docker image which is used to build the fpm docs.
FROM  debian:latest
RUN   apt-get update
RUN   DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip 
RUN   apt-get install -y python3-sphinx #pip3 install Sphinx
#==1.8
RUN   apt-get install -y python3-sphinx python3-sphinx-rtd-theme python3-sphinx-autobuild

CMD ["/bin/bash"] 
