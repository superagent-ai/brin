.PHONY: test

test:
	@cd plugins/cursor && bash scripts/brin-check.test.sh
