.PHONY: test analyze docs-check mvp-docs-check verify-macos

test:
	flutter test

analyze:
	flutter analyze

docs-check:
	python3 scripts/validate_docs_bundle.py

mvp-docs-check:
	$(MAKE) docs-check

verify-macos:
	bash scripts/verify_macos.sh
