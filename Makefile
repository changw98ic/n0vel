.PHONY: test analyze ci-smoke rag-vector-eval docs-check mvp-docs-check verify-macos package-macos-preview

test:
	flutter test

analyze:
	flutter analyze

# Keep routine CI deterministic; the complete suite remains available via test.
ci-smoke:
	flutter test --no-pub -r compact test/main_test.dart test/app_initialization_integration_test.dart test/db_integrity_test.dart

rag-vector-eval:
	dart run tool/rag_vector_index_evaluator.dart --vectors 100000 --dimensions 64

docs-check:
	python3 scripts/validate_docs_bundle.py

mvp-docs-check:
	$(MAKE) docs-check

verify-macos:
	bash scripts/verify_macos.sh

package-macos-preview:
	bash scripts/package_macos_preview.sh
