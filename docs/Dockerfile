# This Dockerfile produces a docker image which is used to build the fpm docs.
FROM  debian:latest
RUN   apt-get update
RUN   DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip 
RUN   pip3 install Sphinx
#==1.8
RUN   pip3 install sphinx_rtd_theme
RUN   pip3 install alabaster 
RUN   pip3 install sphinx-autobuild

CMD ["/bin/bash"] 
