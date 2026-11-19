# The page plays each character's acts by name from assets/characters/index.json, so a name there
# with no file behind it would leave them unable to perform it. Fails if any act lacks its animation.
import json
import os
import sys

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOP_LEVEL = {"walking", "waving", "looking"}

manifest = json.load(open(os.path.join(SITE, "assets", "characters", "index.json")))["characters"]
problems = []
for character in manifest:
    for name in ["walking", *character.get("acts", [])]:
        if character.get("builtin"):
            folder = "assets" if name in TOP_LEVEL else "assets/acts"
            path = os.path.join(SITE, folder, f"clawd-{name}.json")
        else:
            path = os.path.join(SITE, "assets", "characters", character["id"], f"{name}.json")
        try:
            with open(path) as f:
                json.load(f)
        except (OSError, ValueError) as error:
            problems.append(f"{character['id']}/{name}: {error}")
    if not character.get("acts"):
        problems.append(f"{character['id']}: no acts")

# The About window states the app's version; it must match the one being released.
import re
version = open(os.path.join(os.path.dirname(SITE), "deskling", "VERSION")).read().strip()
page = open(os.path.join(SITE, "index.html")).read()
shown = re.search(r'id="about-version">([^<]+)<', page)
if not shown or shown.group(1) != version:
    problems.append(f"About window shows {shown.group(1) if shown else 'no version'}, apps/deskling/VERSION is {version}")

if problems:
    sys.exit("\n".join(problems))
print(f"{len(manifest)} characters, {sum(len(c['acts']) for c in manifest)} acts, each with its animation")
