NAME=jruby
VERSION=1.6.0.RC2
DOWNLOAD=http://jruby.org.s3.amazonaws.com/downloads/$(VERSION)/$(TARBALL)
TARBALL=$(NAME)-bin-$(VERSION).tar.gz
TARDIR=$(NAME)-$(VERSION)

PREFIX=/opt/jruby

.PHONY: default
default: package

.PHONY: clean
clean:
	rm $(NAME)-* $(NAME)_* || true
	rm -r $(TARDIR) || true
	rm *.deb

$(TARBALL):
	wget "$(DOWNLOAD)"

$(TARDIR): $(TARBALL)
	tar -zxf $(TARBALL)

.PHONY: package
package: $(TARDIR)
	fpm -s dir -t deb -v $(VERSION) -n $(NAME) -d "sun-java6-bin" \
		-a all -d "sun-java6-jre" --prefix $(PREFIX) -C $(TARDIR) .
