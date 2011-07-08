NAME=twisted
VERSION=10.2.0

twisted:
	easy_install --editable --build-directory . "$(NAME)==$(VERSION)"

usr: twisted
	cd twisted; python setup.py bdist
	tar -zxf twisted/dist/Twisted-$(VERSION).linux-$(shell uname -m).tar.gz

package: usr
	fpm -s dir -t deb -n $(NAME) -v $(VERSION) \
		-p python-$(NAME)-VERSION_ARCH.deb -d "python" \
		usr

