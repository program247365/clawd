.PHONY: check website-check

check: website-check
	@if [ -f apps/clawd/Makefile ]; then $(MAKE) -C apps/clawd check; fi

# Every act listed in the page must have its animation and its thumbnail.
website-check:
	python3 apps/website/scripts/check-acts.py
