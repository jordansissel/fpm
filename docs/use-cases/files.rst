Jenkins: Single-file package
===================

For this example, you'll learn how to package hudson/jenkins which is a
single-file download.

We'll use `make` to script the download, but `make` isn't required if you don't want it.

Makefile::

    NAME=jenkins
    VERSION=2.80

    .PHONY: package
    package:
      rm -f jenkins.war
      wget https://updates.jenkins-ci.org/download/war/$(VERSION)/jenkins.war
      fpm -s dir -t deb -n $(NAME) -v $(VERSION) --prefix /opt/jenkins jenkins.war

.. note:: You'll need `wget` for this Makefile to work.

Running it::

    % make
    rm -f jenkins.war
    wget https://updates.jenkins-ci.org/download/war/2.80/jenkins.war
    --2017-09-27 14:29:55--  https://updates.jenkins-ci.org/download/war/2.80/jenkins.war
    Resolving updates.jenkins-ci.org (updates.jenkins-ci.org)... 52.202.51.185
    Connecting to updates.jenkins-ci.org (updates.jenkins-ci.org)|52.202.51.185|:443... connected.
    HTTP request sent, awaiting response... 302 Found
    Location: http://mirrors.jenkins-ci.org/war/2.80/jenkins.war [following]
    --2017-09-27 14:29:56--  http://mirrors.jenkins-ci.org/war/2.80/jenkins.war
    Resolving mirrors.jenkins-ci.org (mirrors.jenkins-ci.org)... 52.202.51.185
    Connecting to mirrors.jenkins-ci.org (mirrors.jenkins-ci.org)|52.202.51.185|:80... connected.
    HTTP request sent, awaiting response... 302 Found
    Location: http://ftp-nyc.osuosl.org/pub/jenkins/war/2.80/jenkins.war [following]
    --2017-09-27 14:29:56--  http://ftp-nyc.osuosl.org/pub/jenkins/war/2.80/jenkins.war
    Resolving ftp-nyc.osuosl.org (ftp-nyc.osuosl.org)... 64.50.233.100, 2600:3404:200:237::2
    Connecting to ftp-nyc.osuosl.org (ftp-nyc.osuosl.org)|64.50.233.100|:80... connected.
    HTTP request sent, awaiting response... 200 OK
    Length: 73094442 (70M) [application/x-java-archive]
    Saving to: ‘jenkins.war’

    100%[=======================================================================================================>] 73,094,442  7.71MB/s   in 11s

    2017-09-27 14:30:07 (6.07 MB/s) - ‘jenkins.war’ saved [73094442/73094442]

    % fpm -s dir -t deb -n jenkins -v 1.396 --prefix /opt/jenkins -d "sun-java6-jre (> 0)" jenkins.war
    Created .../jenkins-1.396-1.amd64.deb

Delicious.
