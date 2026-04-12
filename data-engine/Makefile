.PHONY: test lint typecheck check

test:
	.venv/bin/pytest

lint:
	.venv/bin/ruff check src/ tests/

typecheck:
	.venv/bin/pyright src/

check: lint typecheck test
