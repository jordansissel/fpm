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
	@docker run -itv $$PWD:/docs:z $(IMAGE) sh -c 'make -C docs html && chown -R 1000:1000 /docs'

gh-clean:
	@rm -rf "$(WORKDIR)/gh-pages"

$(WORKDIR)/gh-pages: $(WORKDIR)
	@git clone -b gh-pages --single-branch "$(GITROOT)" "$(WORKDIR)/gh-pages"

.PHONY: publish
publish: COMMIT=$(git rev-parse HEAD)
publish: $(WORKDIR)/gh-pages | build
publish:
	@git -C "$(WORKDIR)/gh-pages" remote set-url origin "$(GITREMOTE)"
	@rsync -a --delete --exclude .git _build/html/ "$(WORKDIR)/gh-pages"
	@if git -C "$(WORKDIR)/gh-pages" status -s | grep -q . ; then \
		echo "Publishing changes to gh-pages."; \
		git -C "$(WORKDIR)/gh-pages" add . \
		&& git -C "$(WORKDIR)/gh-pages" commit -m "Generated from $(COMMIT)" \
		&& git -C "$(WORKDIR)/gh-pages" push origin gh-pages; \
	else \
		echo "No changes to publish."; \
	fi
