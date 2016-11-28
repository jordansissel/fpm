include Makefile.sphinx

IMAGE=fpm-sphinx
WORKDIR=./.work
GITROOT=$(shell git rev-parse --show-toplevel)
GITREMOTE=$(shell git remote -v | awk '/(push)/ {print $$2}')

$(WORKDIR):
	mkdir $(WORKDIR)

# A task to generate reST syntax for issue links mentioned in CHANGELOG.rst
changelog_links.rst: ../CHANGELOG.rst Makefile
	grep -Eo '#[0-9]+' $< \
		| tr -d '#' \
		| awk '{printf ".. _#%s: https://github.com/jordansissel/fpm/issues/%s\n", $$1, $$1 }' \
		| sort -u > $@

.PHONY: docker-prep
docker-prep: Dockerfile
	@docker images fpm-sphinx | grep -q '^fpm-sphinx ' \
	|| docker build -t $(IMAGE) .

.PHONY: build
build: changelog_links.rst | docker-prep
	docker run -it -v $$PWD/../:/project:z $(IMAGE) sh -xc 'make -C /project/docs html && chown -R 1000:1000 /project/docs'
