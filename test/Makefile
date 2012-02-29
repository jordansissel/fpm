TESTS=$(shell git ls-files '*.test' | grep -v debconf)

.PHONY: test
test: $(TESTS)

.PHONY: $(TESTS)
$(TESTS):
	@bash test.sh $@

clean:
	rm *.deb *.rpm *.gem
