test:
	$(MAKE) -C tests test

complex-tests:
	$(MAKE) -C tests/complex test

.PHONY: test complex-tests
