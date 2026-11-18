# The page fetches each animation by name, so a name in index.html with no file behind it
# would leave Clawd unable to perform that act. Fails if any act lacks its animation or thumbnail.
import json
import os
import re
import sys

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOP_LEVEL = {"walking", "waving", "looking"}

with open(os.path.join(SITE, "index.html")) as f:
    acts = re.findall(r'data-act="([^"]+)"', f.read())

problems = []
for name in ["walking", *acts]:
    folder = "assets" if name in TOP_LEVEL else "assets/acts"
    path = os.path.join(SITE, folder, f"clawd-{name}.json")
    try:
        with open(path) as f:
            json.load(f)
    except (OSError, ValueError) as error:
        problems.append(f"{name}: {error}")
    if name != "walking" and not os.path.exists(os.path.join(SITE, "assets/thumbs", f"{name}.png")):
        problems.append(f"{name}: no thumbnail")

if not acts:
    problems.append("index.html lists no acts")
if problems:
    sys.exit("\n".join(problems))
print(f"{len(acts)} acts, each with an animation and a thumbnail")
