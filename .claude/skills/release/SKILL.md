---
name: release
description: Use when Kevin asks to cut, ship, or publish a new version of the Deskling Mac app ("cut a release", "ship 0.5.0", "do everything"). Covers picking the version, bumping it in the app and on the site, pushing, building/signing/notarizing the DMG, writing release notes and the update bubble lines, publishing the GitHub release, Sparkle update feed, and Homebrew cask, and verifying all of it landed.
---

# Releasing Deskling

A release touches four places: the repo (`main`), Apple's notary service, a GitHub release, and the
Homebrew tap `program247365/homebrew-tap`. The site at deskling.kbr.sh redeploys itself from `main`.
The GitHub release also carries `appcast.xml`, the Sparkle feed every installed copy checks daily at
`releases/latest/download/appcast.xml`: publishing a release is what offers it to everyone.
"Cut a release" or "do everything" is Kevin's go-ahead for all of the steps below, pushes included.

## 1. Preflight (before anything leaves the machine)

Run from the repo root; stop and tell Kevin if any fails.

```sh
xcrun notarytool history --keychain-profile clawd-notary >/dev/null && echo notary-ok
gh auth status
security find-identity -v -p codesigning | grep 'Developer ID Application'
apps/deskling/.build/artifacts/sparkle/Sparkle/bin/generate_keys -p   # must print DG2iFMiF…; the update key
git fetch -q && git status -sb    # clean, on main; ahead of origin is fine
make check
```

If `generate_keys -p` finds no key (a new Mac), restore it from 1Password (item "Deskling Sparkle update key",
vault Private). Kevin may need to unlock 1Password first (`! op signin`). Never print the key:

```sh
d=$(mktemp -d) && (umask 077; op read 'op://Private/Deskling Sparkle update key/password' > "$d/k") \
  && apps/deskling/.build/artifacts/sparkle/Sparkle/bin/generate_keys -f "$d/k"; rm -P "$d/k"; rmdir "$d"
```

Never generate a new key: copies already installed only accept updates signed with this one.

The notary profile keeps its pre-rename name, `clawd-notary`. If it is missing, give Kevin the
`xcrun notarytool store-credentials` line from `apps/deskling/scripts/release.sh`; it prompts for a password, so he runs it.

## 2. Pick the version

Read `apps/deskling/VERSION` and the commits since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`).
Bump the minor version for new behavior, the patch version for fixes only. If Kevin named a version, use his.

## 3. Bump, commit, push

The version lives in two files, and `make check` (`apps/website/scripts/check-acts.py`) fails if they disagree:

- `apps/deskling/VERSION`
- `apps/website/index.html`: `<span id="about-version">X.Y.Z</span>`

Commit just those two files as `Deskling X.Y.Z`, with a one-line summary of what is new in the body and
the usual Co-Authored-By trailer. Push `main`. `make publish` refuses unless HEAD is the pushed tip of `origin/main`.

## 4. Build, sign, notarize

```sh
make release
```

Takes a few minutes. It reruns `make check`, builds a universal app, signs it, uploads the DMG to Apple, waits,
staples it, and leaves `apps/deskling/dist/Deskling.dmg` and `Deskling-X.Y.Z.dmg`. It ends with `spctl` printing
`source=Notarized Developer ID` for the app and the DMG; anything else is a failure. It is safe to rerun.

Packaging scripts Finder to lay out the DMG window (background, icon positions), so it needs a logged-in desktop:
the first run asks to let the terminal control Finder, and it stops if a volume named Deskling is already mounted.

## 5. Release notes and bubble lines

Write both to files in the scratchpad, never in the repo.

**Bubble lines** (`BUBBLE=`): one to three lines, 40 characters at most each, that the character says
in its speech bubble when offering the update, between "Psst! Deskling X.Y.Z is out" and "Click me to update".
Playful and concrete, e.g. "You can pet them now!". `make publish` refuses lines that are too many or too long.

**Release notes** (`NOTES=`): Match earlier releases (`gh release view --json body`):
short `## New` / `## Changed` / `## Fixed` sections as needed, user-facing language (what they see on their desktop,
not class names), first person and playful per PRODUCT.md, an artist section only if Aseprite tags changed, and end with:

```
Install with `brew install --cask program247365/tap/deskling`, or `brew upgrade --cask deskling` if you have it.
```

Never mention Claude or AI in the notes.

## 6. Publish

```sh
make publish NOTES=<notes file> BUBBLE=<bubble file>
```

This signs the DMG with the update key from the keychain and writes `appcast.xml`, then creates release `vX.Y.Z`
with `Deskling-X.Y.Z.dmg`, `Deskling.dmg`, `Clawd.dmg` (kept for links from before the rename), and `appcast.xml`.
Then it commits the new version and sha256 to the cask in the tap and pushes it. It refuses to run twice for one version.

## 7. Verify

```sh
gh release view vX.Y.Z --json name,assets --jq '.name, .assets[].name'
gh api repos/program247365/homebrew-tap/contents/Casks/deskling.rb --jq .content | base64 -d | grep -E 'version|sha256'
shasum -a 256 apps/deskling/dist/Deskling-X.Y.Z.dmg            # must equal the cask's sha256
curl -sL https://github.com/program247365/deskling/releases/latest/download/appcast.xml   # X.Y.Z, edSignature, the bubble lines
apps/deskling/.build/artifacts/sparkle/Sparkle/bin/sign_update --verify apps/deskling/dist/Deskling-X.Y.Z.dmg <edSignature from the feed>
curl -s https://deskling.kbr.sh/ | grep -A1 about-version       # the site shows X.Y.Z (Vercel takes up to a minute)
curl -sIL https://github.com/program247365/deskling/releases/latest/download/Deskling.dmg | grep -i content-length
```

Report the release URL and each check's result to Kevin. If a step failed part-way, say exactly which ran:
a pushed bump with no GitHub release is fine to finish later, but a GitHub release without the cask bump
means `brew upgrade` users miss it, so rerun only the cask part of `scripts/publish.sh` by hand rather than the whole script.

## Gotchas

- Sparkle refuses `file://` feeds. To try an update locally without publishing, serve a test feed with
  `python3 -m http.server --bind 127.0.0.1` and point a scratch copy's `SUFeedURL` at `http://localhost:<port>/appcast.xml`.

- A local `make run` build and the installed `/Applications/Deskling.app` share a bundle ID; quit one before opening the other.
- `make release` signs with `Developer ID Application: Kevin Ridgway (2RGYH2QYUY)` unless `APP_IDENTITY` is set.
- `SKIP_NOTARIZE=1 make release` tests everything but Apple's step. Never publish that DMG.
