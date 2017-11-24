test:
	$(MAKE) -C tests test

test-complex:
	$(MAKE) -C tests/complex test

.PHONY: test test-complex
