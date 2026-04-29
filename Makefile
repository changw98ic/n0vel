.PHONY: mvp-docs-check verify-macos

mvp-docs-check:
	python3 docs/mvp/validate_mvp_docs.py

verify-macos:
	bash scripts/verify_macos.sh
