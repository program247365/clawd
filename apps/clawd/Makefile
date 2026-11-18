SITE_ASSETS := ../website/assets
ANIMATIONS := .build/animations

.PHONY: animations check

animations:
	rm -rf $(ANIMATIONS)
	mkdir -p $(ANIMATIONS)
	for name in walking waving looking; do \
		cp $(SITE_ASSETS)/clawd-$$name.json $(ANIMATIONS)/$$name.json; \
	done
	for file in $(SITE_ASSETS)/acts/clawd-*.json; do \
		name=$$(basename $$file); \
		cp $$file $(ANIMATIONS)/$${name#clawd-}; \
	done

check: animations
	swift build
	swift test
