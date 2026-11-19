# Copies each drawn character from apps/deskling/characters into the site, and writes the manifest
# the page reads: assets/characters/index.json. Clawd is listed first; his files are the site's own.
#
#   python3 scripts/sync-characters.py           write the copies and the manifest
#   python3 scripts/sync-characters.py --check   exit 1 if the site's copies have drifted
#
# Each character's still (stand.png, for when the animation library does not load) is rendered by
# `make -C apps/deskling site-characters`, which runs this script first.
import json
import os
import shutil
import sys

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(os.path.dirname(SITE), "deskling", "characters")
TARGET = os.path.join(SITE, "assets", "characters")
# Played by the page's walker and the lineup, never as a random act. The rest have jobs of their own
# in the app (Character.drawnReservedActs): a one-frame pose, and what only you or an agent set off.
NOT_ACTS = {"walking", "ready", "looking", "celebrate", "pet", "nap", "wake"}

CLAWD = {
    "id": "clawd",
    "name": "Clawd",
    "blurb": "The original. Orange, earnest, always busy.",
    # The page's own clawd-walking.json: frames 5-24 are the step cycle, 26 the stand.
    "walkCycle": [5, 25],
    "standingFrame": 26,
    "ready": False,
    "builtin": True,
}


def clawd():
    """Clawd's entry: his acts are the site's own files, assets/acts/clawd-*.json plus the two beside the walk."""
    acts = sorted(name[len("clawd-"):-len(".json")] for name in os.listdir(os.path.join(SITE, "assets", "acts"))
                  if name.startswith("clawd-") and name.endswith(".json"))
    return {**CLAWD, "acts": sorted(acts + ["looking", "waving"])}


def drawn_characters():
    for id in sorted(os.listdir(SOURCE)):
        folder = os.path.join(SOURCE, id)
        if not os.path.isfile(os.path.join(folder, "character.json")):
            continue
        info = json.load(open(os.path.join(folder, "character.json")))
        meta = json.load(open(os.path.join(folder, "meta.json")))
        animations = sorted(name[:-5] for name in os.listdir(os.path.join(folder, "animations")) if name.endswith(".json"))
        yield id, folder, {
            "id": id,
            "name": info["name"],
            "blurb": info.get("blurb", ""),
            # Lottie segments end one past the last frame.
            "walkCycle": [meta["walkCycle"][0], meta["walkCycle"][1] + 1],
            "standingFrame": meta["standingFrame"],
            "ready": "ready" in animations,
            "acts": [name for name in animations if name not in NOT_ACTS],
        }


def expected_files():
    """Every file the site should hold, as {site path: source path or manifest text}."""
    files, manifest = {}, [clawd()]
    for id, folder, entry in drawn_characters():
        manifest.append(entry)
        for name in os.listdir(os.path.join(folder, "animations")):
            if name.endswith(".json"):
                files[os.path.join(TARGET, id, name)] = os.path.join(folder, "animations", name)
    files[os.path.join(TARGET, "index.json")] = json.dumps({"characters": manifest}, indent=2) + "\n"
    return files


def same(path, source):
    if not os.path.isfile(path):
        return False
    if os.path.isfile(source):
        return open(path, "rb").read() == open(source, "rb").read()
    return open(path).read() == source


def main():
    files = expected_files()
    if "--check" in sys.argv:
        stale = [os.path.relpath(path, SITE) for path, source in files.items() if not same(path, source)]
        if stale:
            sys.exit("Site characters are out of date (run make -C apps/deskling site-characters):\n  " + "\n  ".join(stale))
        print(f"{len(files) - 1} character files match apps/deskling/characters")
        return
    for path, source in files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if os.path.isfile(source):
            shutil.copyfile(source, path)
        else:
            open(path, "w").write(source)
    print(f"wrote {len(files)} files to {os.path.relpath(TARGET, SITE)}")


main()
