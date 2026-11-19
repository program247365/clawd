SITE_ASSETS := ../website/assets
ANIMATIONS := .build/animations

.PHONY: animations check icons thumbs readme-gif app run release

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

# Regenerates the committed icons from the art (walking frame 26, the standing pose).
icons: animations
	swift build --product IconTool
	rm -rf .build/icons && mkdir -p .build/icons Resources
	.build/debug/IconTool $(ANIMATIONS) .build/icons
	iconutil -c icns .build/icons/AppIcon.iconset -o Resources/AppIcon.icns
	cp .build/icons/MenuIcon.png .build/icons/MenuIcon@2x.png Resources/

# Regenerates the website's act thumbnails (the middle frame of each act).
thumbs: animations
	swift build --product IconTool
	.build/debug/IconTool --thumbs $(ANIMATIONS) ../website/assets/thumbs

# Regenerates the waving Clawd at the top of the README (needs ImageMagick).
readme-gif: animations
	swift build --product IconTool
	rm -rf .build/readme-frames
	.build/debug/IconTool --frames $(ANIMATIONS) waving .build/readme-frames
	mkdir -p ../../docs
	magick -delay 1x12 -dispose background -loop 0 .build/readme-frames/frame-*.png \
		-layers trim-bounds -filter point -resize 50% ../../docs/clawd-waving.gif

# A local, ad-hoc signed build for this machine's architecture.
app: animations
	swift build -c release --product Clawd
	scripts/assemble.sh "$$(swift build -c release --show-bin-path)"
	codesign --force --sign - dist/Clawd.app

run: app
	open dist/Clawd.app

# Universal, Developer ID signed, notarized DMG. See scripts/release.sh for the one-time setup.
release:
	scripts/release.sh
