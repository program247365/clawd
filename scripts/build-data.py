# Bundles the Lottie JSON files into assets/clawd-data.js so index.html works from file://
# (browsers block fetch() of local JSON). Keys are file names minus "clawd-" and ".json".
import glob
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
FILES = [f"assets/clawd-{n}.json" for n in ("walking", "waving", "looking")]
FILES += sorted(os.path.relpath(p, ROOT) for p in glob.glob(os.path.join(ROOT, "assets/acts/clawd-*.json")))

data = {}
for path in FILES:
    with open(os.path.join(ROOT, path)) as f:
        data[os.path.basename(path)[len("clawd-"):-len(".json")]] = json.load(f)

with open(os.path.join(ROOT, "assets/clawd-data.js"), "w") as f:
    f.write("window.CLAWD=" + json.dumps(data, separators=(",", ":")) + ";")

print(f"{len(data)} animations: {', '.join(data)}")
