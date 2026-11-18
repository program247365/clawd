.PHONY: check website-check

check: website-check
	@if [ -f apps/clawd/Makefile ]; then $(MAKE) -C apps/clawd check; fi

website-check:
	python3 apps/website/scripts/build-data.py
	git diff --quiet -- apps/website/assets/clawd-data.js
