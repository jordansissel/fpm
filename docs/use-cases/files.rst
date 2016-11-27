Jenkins: Single-file package
===================

For this example, you'll learn how to package hudson/jenkins which is a
single-file download.

We'll use `make` to script the download, but `make` isn't required if you don't want it.

Makefile::

    NAME=jenkins
    VERSION=1.396

    .PHONY: package
    package:
      rm -f jenkins.war
      wget http://ftp.osuosl.org/pub/hudson/war/$(VERSION)/jenkins.war
      fpm -s dir -t deb -n $(NAME) -v $(VERSION) --prefix /opt/jenkins jenkins.war

.. note:: You'll need `wget` for this Makefile to work.

Running it::

    % make
    rm -f jenkins.war
    wget http://ftp.osuosl.org/pub/hudson/war/1.396/jenkins.war
    --2011-02-07 17:56:01--  http://ftp.osuosl.org/pub/hudson/war/1.396/jenkins.war
    Resolving ftp.osuosl.org... 140.211.166.134
    Connecting to ftp.osuosl.org|140.211.166.134|:80... connected.
    HTTP request sent, awaiting response... 200 OK
    Length: 36665038 (35M) [text/plain]
    Saving to: `jenkins.war'

    100%[====================================================>] 36,665,038  3.88M/s   in 10s     

    2011-02-07 17:56:11 (3.37 MB/s) - `jenkins.war' saved [36665038/36665038]

    % fpm -s dir -t deb -n jenkins -v 1.396 --prefix /opt/jenkins -d "sun-java6-jre (> 0)" jenkins.war
    Created .../jenkins-1.396-1.amd64.deb

Delicious.

