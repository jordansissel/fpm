TESTS=$(shell git ls-files '*.test')

.PHONY: test
test: $(TESTS)

.PHONY: $(TESTS)
$(TESTS):
	@bash test.sh $@

clean:
	rm *.deb *.rpm *.gem
