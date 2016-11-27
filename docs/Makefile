include Makefile.sphinx

IMAGE=fpm-sphinx
WORKDIR=./.work
GITROOT=$(shell git rev-parse --show-toplevel)
GITREMOTE=$(shell git remote -v | awk '/(push)/ {print $$2}')

$(WORKDIR):
	mkdir $(WORKDIR)

.PHONY: docker-prep
docker-prep: Dockerfile
	@docker images fpm-sphinx | grep -q '^fpm-sphinx ' \
	|| docker build -t $(IMAGE) .

.PHONY: build
build: | docker-prep
	docker run -it -v $$PWD/../:/project:z $(IMAGE) sh -xc 'make -C /project/docs html && chown -R 1000:1000 /project/docs'
