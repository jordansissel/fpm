NAME=jruby
VERSION=1.6.1
DOWNLOAD=http://jruby.org.s3.amazonaws.com/downloads/$(VERSION)/$(TARBALL)
TARBALL=$(NAME)-bin-$(VERSION).tar.gz
TARDIR=$(NAME)-$(VERSION)

PREFIX=/opt/jruby

.PHONY: default
default: deb
package: deb

.PHONY: clean
clean:
	rm -f $(NAME)-* $(NAME)_* || true
	rm -fr $(TARDIR) || true
	rm -f *.deb
	rm -f *.rpm

$(TARBALL):
	wget "$(DOWNLOAD)"

$(TARDIR): $(TARBALL)
	tar -zxf $(TARBALL)

.PHONY: deb
deb: $(TARDIR)
	fpm -s dir -t deb -v $(VERSION) -n $(NAME) -d "sun-java6-bin (>> 0)" \
		-a all -d "sun-java6-jre (>> 0)" --prefix $(PREFIX) -C $(TARDIR) .

.PHONY: rpm
rpm: $(TARDIR)
	fpm -s dir -t rpm -v $(VERSION) -n $(NAME) -d "jdk >= 1.6.0" \
		-a all --prefix $(PREFIX) -C $(TARDIR) .

