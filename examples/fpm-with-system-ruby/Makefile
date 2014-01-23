#
# feel free to change these to whatever makes sense
#
# debian package we rely on
RUBY_PACKAGE=ruby
# and the executable that comes from it
RUBY_BIN=/usr/bin/ruby
# the version we name the deb
VERSION=1.0.2
# where to get the sauce
GIT_URL=https://github.com/jordansissel/fpm.git
# the tag we checkout to build from
TAG_SPEC=refs/tags/v$(VERSION)

# these chaps are a bit more hardcoded
CHECKOUT_DIR=fpm-checkout
BUILD_DIR=build
INSTALL_DIR=$(BUILD_DIR)/usr/lib/fpm
GEM_PATH:=$(shell readlink -f .)/build/gem
BIN_DIR=$(BUILD_DIR)/usr/bin
FPM_BIN=$(BIN_DIR)/fpm
BUNDLE_BIN=$(GEM_PATH)/bin/bundle
BUNDLE_CMD=$(RUBY_CMD) $(BUNDLE_BIN)
FPM_CMD=$(FPM_BIN)
GEM_CMD=$(RUBY_BIN) -S gem

.PHONY: clean
clean:
	rm -rf $(CHECKOUT_DIR)
	rm -rf $(BUILD_DIR)
	rm -f fpm*.deb

$(CHECKOUT_DIR):
	rm -rf $(CHECKOUT_DIR)
	git clone $(GIT_URL) $(CHECKOUT_DIR) --depth 1
	cd $(CHECKOUT_DIR) && git checkout $(TAG_SPEC)

$(BUNDLE_BIN):
	$(GEM_CMD) install bundler --install-dir=$(GEM_PATH) --no-ri --no-rdoc

$(FPM_BIN):
	mkdir --parents $(BIN_DIR)
# 	don't hate me - perhaps just show me a better way?
	echo "#! $(RUBY_BIN)" > $(FPM_BIN)
	echo 'load File.dirname($$0) + "/../lib/fpm/bundle/bundler/setup.rb"' >> $(FPM_BIN)
	echo 'require "fpm"'  >> $(FPM_BIN)
	echo 'require "fpm/command"' >> $(FPM_BIN)
	echo 'exit(FPM::Command.run || 0)' >> $(FPM_BIN)
	chmod +x $(FPM_BIN)

.PHONY: install
install: $(CHECKOUT_DIR) $(BUNDLE_BIN) $(FPM_BIN)
	mkdir --parents $(INSTALL_DIR)
	cd $(CHECKOUT_DIR) && GEM_PATH=$(GEM_PATH) $(BUNDLE_CMD) install --without=development --standalone
	cd $(CHECKOUT_DIR) && gem build fpm.gemspec
	tar -xf $(CHECKOUT_DIR)/fpm*gem -C $(BUILD_DIR)
	tar --touch -xf $(BUILD_DIR)/data.tar.gz -C $(INSTALL_DIR)
	cp -r $(CHECKOUT_DIR)/bundle $(INSTALL_DIR)/bundle

.PHONY: package
package: install
	$(FPM_BIN) -s dir -t deb -n fpm -d $(RUBY_PACKAGE) -v $(VERSION) -C $(BUILD_DIR) usr
