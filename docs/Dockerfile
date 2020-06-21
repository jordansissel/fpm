# This Dockerfile produces a docker image which is used to build the fpm docs.
FROM  debian:latest
RUN   apt-get update
RUN   DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip 
RUN   pip install Sphinx==1.8
RUN   pip install sphinx_rtd_theme
RUN   pip install alabaster 

CMD ["/bin/bash"] 
