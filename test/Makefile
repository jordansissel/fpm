TESTS=$(shell git ls-files '*.test')

.PHONY: test
test: $(TESTS)

.PHONY: $(TESTS)
$(TESTS):
	@sh test.sh $@

clean:
	rm *.deb *.rpm *.gem
