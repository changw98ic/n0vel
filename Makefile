.PHONY: test analyze rag-vector-eval docs-check mvp-docs-check verify-macos verify-macos-ci package-macos-preview

test:
	flutter test

analyze:
	flutter analyze

rag-vector-eval:
	dart run tool/rag_vector_index_evaluator.dart --vectors 100000 --dimensions 64

docs-check:
	python3 scripts/validate_docs_bundle.py

mvp-docs-check:
	$(MAKE) docs-check

verify-macos:
	bash scripts/verify_macos.sh

verify-macos-ci:
	bash scripts/verify_macos.sh --skip-flutter-analyze --skip-flutter-tests

package-macos-preview:
	bash scripts/package_macos_preview.sh
