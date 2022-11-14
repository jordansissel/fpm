include Makefile.sphinx

IMAGE=fpm-sphinx
WORKDIR=./.work
GITROOT=$(shell git rev-parse --show-toplevel)
GITREMOTE=$(shell git remote -v | awk '/(push)/ {print $$2}')

GENERATED_FILES=cli-reference.rst changelog_links.rst

$(WORKDIR):
	mkdir $(WORKDIR)

# A task to generate reST syntax for issue links mentioned in CHANGELOG.rst
changelog_links.rst: ../CHANGELOG.rst Makefile
	grep -Eo '#[0-9]+' $< \
		| tr -d '#' \
		| awk '{printf ".. _#%s: https://github.com/jordansissel/fpm/issues/%s\n", $$1, $$1 }' \
		| sort -u > $@

# CLI reference is generated based on the the command line flags
cli-reference.rst: generate-cli-reference.rb Makefile
cli-reference.rst: ../lib/fpm/package/*.rb ../lib/fpm/package.rb
	ruby -I ../lib generate-cli-reference.rb > $@

package-type-cli: 
	$(MAKE) $(addprefix packages/cli/,$(addsuffix .rst,$(notdir $(basename $(wildcard ../lib/fpm/package/*.rb)))))

packages/cli:
	mkdir $@

packages/cli/%.rst: ../lib/fpm/package/%.rb packages/cli generate-cli-reference.rb Makefile
	ruby -I ../lib generate-cli-reference.rb $* > $@


.PHONY: podman-prep
podman-prep: Dockerfile
	@podman images fpm-sphinx | grep -q '^fpm-sphinx ' \
	|| podman build -t $(IMAGE) .

.PHONY: build
build: $(GENERATED_FILES) | podman-prep
	podman run -it -v $$PWD/../:/project:z $(IMAGE) sh -xc 'make -C /project/docs html && chown -R 1000:1000 /project/docs'


.PHONY: build
view: $(GENERATED_FILES) | podman-prep
	podman run -p 127.0.0.1:8000:8000 -it -v $$PWD/../:/project:z $(IMAGE) sh -xc 'make -C /project/docs livehtml'
