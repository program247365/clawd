SITE_ASSETS := ../website/assets
ANIMATIONS := .build/animations
CHARACTERS := .build/characters
ASEPRITE ?= /Applications/Aseprite.app/Contents/MacOS/aseprite

.PHONY: animations check icons thumbs readme-gif app run release new-character export-characters site-characters

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
	rm -rf $(CHARACTERS)
	mkdir -p $(CHARACTERS)
	for dir in characters/*/; do \
		[ -f $$dir/character.json ] && [ -f $$dir/meta.json ] || continue; \
		id=$$(basename $$dir); \
		mkdir -p $(CHARACTERS)/$$id/animations; \
		cp $$dir/character.json $$dir/meta.json $(CHARACTERS)/$$id/; \
		cp $$dir/animations/*.json $(CHARACTERS)/$$id/animations/; \
	done

check: animations
	swift build
	swift test

# A starter file to draw a new character in: make new-character ID=pip
new-character: animations
	@test -n "$(ID)" || (echo "Usage: make new-character ID=<id>" >&2; exit 1)
	@test ! -e characters/$(ID)/$(ID).aseprite || (echo "characters/$(ID)/$(ID).aseprite already exists" >&2; exit 1)
	mkdir -p characters/$(ID)
	$(ASEPRITE) -b --script-param clawd=$(CURDIR)/$(ANIMATIONS) \
		--script-param out=$(CURDIR)/characters/$(ID)/$(ID).aseprite --script scripts/aseprite/new-character.lua
	@test -f characters/$(ID)/character.json || \
		printf '{\n  "name": "%s",\n  "blurb": ""\n}\n' "$(ID)" > characters/$(ID)/character.json

# Exports each drawn character's tags into its animations folder. The results are committed, so
# building the app never needs Aseprite. A tag you rename or delete leaves its old file behind.
export-characters:
	for file in characters/*/*.aseprite; do \
		dir=$$(dirname $$file); \
		mkdir -p $$dir/animations; \
		$(ASEPRITE) -b --script-param file=$(CURDIR)/$$file --script-param out=$(CURDIR)/$$dir \
			--script scripts/aseprite/export-character.lua || exit 1; \
	done

# Copies the drawn characters into the website, with a still of each one standing for when the
# page's animation library does not load.
site-characters: animations
	python3 ../website/scripts/sync-characters.py
	swift build --product IconTool
	for dir in $(CHARACTERS)/*/; do \
		id=$$(basename $$dir); \
		frame=$$(python3 -c "import json; print('%03d' % json.load(open('$$dir/meta.json'))['standingFrame'])"); \
		mkdir -p .build/stills/$$id; \
		.build/debug/IconTool --frames $$dir/animations walking .build/stills/$$id >/dev/null; \
		sips -Z 220 .build/stills/$$id/frame-$$frame.png --out ../website/assets/characters/$$id/stand.png >/dev/null; \
	done
	mkdir -p .build/stills/clawd ../website/assets/characters/clawd
	.build/debug/IconTool --frames $(ANIMATIONS) walking .build/stills/clawd >/dev/null
	sips -Z 220 .build/stills/clawd/frame-026.png --out ../website/assets/characters/clawd/stand.png >/dev/null

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
	swift build -c release --product Deskling
	swift build -c release --product deskling-hook
	scripts/assemble.sh "$$(swift build -c release --show-bin-path)"
	codesign --force --sign - dist/Deskling.app/Contents/Helpers/deskling-hook
	codesign --force --sign - dist/Deskling.app

run: app
	open dist/Deskling.app

# Universal, Developer ID signed, notarized DMG. See scripts/release.sh for the one-time setup.
release:
	scripts/release.sh
