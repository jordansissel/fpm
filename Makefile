GEMSPEC=$(shell ls *.gemspec)
VERSION=$(shell awk -F\" '/VERSION =/ { print $$2 }' lib/fpm/version.rb)
NAME=$(shell awk -F\" '/spec.name/ { print $$2 }' $(GEMSPEC))
GEM=$(NAME)-$(VERSION).gem

.PHONY: test
test:
	rm -rf .yardoc
	sh notify-failure.sh rspec

.PHONY: testloop
testloop:
	while true; do \
		$(MAKE) test; \
		$(MAKE) wait-for-changes; \
	done

.PHONY: serve-coverage
serve-coverage:
	cd coverage; python -mSimpleHTTPServer

.PHONY: wait-for-changes
wait-for-changes:
	-inotifywait --exclude '\.swp' -e modify $$(find $(DIRS) -name '*.rb'; find $(DIRS) -type d)

.PHONY: package
package: | $(GEM)

.PHONY: gem
gem: $(GEM)

$(GEM):
	gem build $(GEMSPEC)

.PHONY: test-package
test-package: $(GEM)
	# Sometimes 'gem build' makes a faulty gem.
	gem unpack $(GEM)
	rm -rf ftw-$(VERSION)/

.PHONY: publish
publish: test-package
	gem push $(GEM)

.PHONY: install
install: $(GEM)
	gem install $(GEM)

.PHONY:
clean:
	rm -rf package-*/ *.rpm *.deb *.gz *.tar *.gem .yardoc/

publish-docs:
	$(MAKE) -C docs publish

# Testing in docker.
# The dot file is a sentinal file that will built a docker image, and tag it.
# The normal make target runs said image, mounting CWD against it.
SECONDARY: .docker-test-minimal .docker-test-everything
.docker-test-%: Gemfile.lock fpm.gemspec Dockerfile
	DOCKER_BUILDKIT=1 docker build -t fpm-test-$*  --build-arg BASE_ENV=$* --build-arg TARGET=test .
	touch "$@"

docker-test-%: .docker-test-%
	docker run -v `pwd`:/src fpm-test-$*

docker-release-%:
	DOCKER_BUILDKIT=1 docker build -t fpm  --build-arg BASE_ENV=$* --build-arg TARGET=release --squash .

