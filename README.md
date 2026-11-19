<p align="center">
  <img src="docs/clawd-waving.gif" width="260" alt="Clawd, a small orange pixel creature, waving hello">
</p>

<h1 align="center">Deskling</h1>

<p align="center">
  Little pixel friends that live along the bottom of your Mac's screen, and come and find you when your coding agent needs you.
</p>

<p align="center">
  <a href="https://github.com/program247365/clawd/releases/latest"><img src="https://img.shields.io/github/v/release/program247365/clawd?style=flat-square" alt="Latest release"></a>
  <a href="#install"><img src="https://img.shields.io/badge/platform-macOS%2014%2B-555?style=flat-square" alt="macOS 14 or later"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/program247365/clawd?style=flat-square" alt="License"></a>
  <a href="https://github.com/program247365/homebrew-tap"><img src="https://img.shields.io/badge/Homebrew-program247365%2Ftap-FBB040?style=flat-square&logo=homebrew&logoColor=white" alt="Homebrew tap"></a>
</p>

<p align="center">
  <b>Clawd is Anthropic's character. This is an unofficial fan project.</b>
</p>

---

Pick a Deskling and they live in your menubar and walk along the bottom of your screen. Every so often they stop to perform: Clawd fishes and juggles, Minx leaps onto a pumpkin, Sol sets and rises again, Luna goes through her phases. Clicks pass straight through them, so they never get in the way.

The cast:

| | |
| --- | --- |
| **Clawd** | The original. Orange, earnest, always busy. |
| **Octo** | A spotted purple octopus with a long wavy arm. |
| **Minx** | A curious black cat. Especially curious about pumpkins. |
| **Sol** | The sun, up early and out late. |
| **Luna** | The moon, sleepy and soft. |

See Clawd in a browser at **[clawd.kbr.sh](https://clawd.kbr.sh)**.

## Install

The current release is still called Clawd and has only Clawd; the next release ships as Deskling with the whole cast, and the cask becomes `deskling`. If you installed with Homebrew, `brew upgrade` moves you across.

```sh
brew install --cask program247365/tap/clawd
```

Or download [Clawd.dmg](https://github.com/program247365/clawd/releases/latest/download/Clawd.dmg), open it, and drag the app to Applications.

Requires macOS 14 or later, on Apple silicon or Intel. The app is signed and notarized. Windows and Linux are planned.

Coming from Clawd? Deskling brings your settings across the first time it runs. Turn Launch at Login back on from the menu; macOS treats Deskling as a new app.

## Quick start

```sh
open -a Deskling
```

The first time, you pick your Deskling on a character-select screen: arrow keys and Enter, or click. They drop in from the top of the screen under a spotlight, land, wave, and get going. Their icon appears in the menubar.

## What a Deskling does

| | |
| --- | --- |
| **Makes an entrance** | On launch they fall in under a stage spotlight, land, and wave. |
| **Walks and performs** | They patrol the bottom of the screen, on top of the Dock, and play each of their acts once before repeating any. |
| **Roams, if you let them** | They stay at the bottom by default. Choose "Let them roam!" in Settings and about one time in four they pop up somewhere else to perform. |
| **Notices you** | Bring the cursor near and they stop, turn to face it, and look up if it's above them. Leave it there and after a while they get back to work. |
| **Visits your lock screen** | Turn on "Bring them along to the lock screen" and they keep walking while your Mac is locked. |
| **Stays out of the way** | They sit above your windows but never take a click, a scroll, or focus, and they step aside for fullscreen apps. |
| **Fits your screen** | Small, Medium, or Large, from the menu. |

From the menubar you can switch characters, hide them, change their size, turn on Launch at Login, and open Settings (⌘,).

### About the lock screen visit

macOS has no official way for an app to appear on the lock screen. Deskling gets there with private window-server functions, so the option is off by default, and a macOS update could break it. If the functions are missing, the option turns itself off. It is confirmed on macOS 27 and untested on earlier versions.

### Claude Code and Codex

Your Deskling can act out what your coding agents are doing (thinking, typing, editing, browsing), celebrate when one finishes, and walk to the middle of the screen to wave when one is waiting on you. The wave lasts until you answer. Both are on by default in Settings and do nothing until an agent is connected.

**Claude Code:** run this in a session:

```
/plugin install deskling --marketplace program247365/clawd
```

**Codex:** open Settings, choose **Connect Codex**, then trust the new hooks in Codex with `/hooks`. Connecting adds Deskling's hooks to `~/.codex/hooks.json` without touching any you already have, and keeps the previous file as `hooks.json.before-deskling`. **Disconnect Codex** removes only Deskling's hooks. Codex calls them over when it asks for approval (its `PermissionRequest` hook). Codex has no idle notification, so they only celebrate when a Codex turn ends.

The hooks send the app only the event type, the session id, the project folder's name, and the tool name. Prompts, commands, and file contents never leave the agent. If the app isn't running, the hooks do nothing. Any other agent can join in by running `Deskling.app/Contents/Helpers/deskling-hook --agent <name> --event <kind>`. The event kinds are listed in `apps/deskling/Sources/DesklingHook/main.swift`.

## Development

The repo holds two apps:

| Path | What |
| --- | --- |
| `apps/deskling` | the Mac app (Swift package) |
| `apps/website` | the clawd.kbr.sh site and the animation files |

Building needs a Swift 6 toolchain (Xcode 16 or newer). Everything runs from the repository root; `make` on its own lists every task.

```sh
make check
```

`make check` verifies every act on the site has its animation and thumbnail, builds the app, and runs the tests, including one that renders every animation.

To run a local build of the app:

```sh
make run
```

That builds `apps/deskling/dist/Deskling.app` for your Mac with an ad-hoc signature. `make site` serves the website locally. Tasks that regenerate things made from the art live in the app's own Makefile: `make -C apps/deskling icons`, `thumbs`, and `readme-gif`.

### Drawing a new character

Characters are drawn in [Aseprite](https://www.aseprite.org) and exported to Lottie files in the same format as Clawd's, so the app treats them all alike.

```sh
make -C apps/deskling new-character ID=pip    # apps/deskling/characters/pip/pip.aseprite + character.json
make -C apps/deskling export-characters       # writes each character's animations/ folder
```

The starter file is 27 x 18 pixels. One pixel is one of Clawd's body pixels, and the bottom row is the floor. Each tag holds Clawd traced onto a faded `reference` layer with his timing (12fps); draw on the `art` layer. The exporter skips any layer whose name starts with `ref`.

| Tag | Used for |
| --- | --- |
| `walk`, `stand` | Required. The step loop, and one standing frame |
| `wave` | The entrance, the character-select pick, and the "needs you" alert |
| `look-up` | One frame, eyes up, for when the cursor is above them |
| `ready` | The character-select idle, fists up. Without it, their standing pose bounces through a crouch |
| `think`, `type`, `write`, `browse`, `search`, `delegate`, `compact`, `celebrate` | What agents are doing. Any you leave out are skipped |
| anything else | An extra act in the routine |

Set the name and blurb in `character.json`. Commit the exported `animations/` folder too, so building the app never needs Aseprite. The character shows up on the character-select screen and under **Character** in the menu, and gets a menubar icon made from their standing pose. If their eyes are not near-black, list the eye color in `character.json` as `"iconHoles": ["#e9b03a"]` so the icon cuts them out.

### Releasing

`make release` builds a universal app, signs it with a Developer ID, notarizes it with Apple, and leaves `Deskling.dmg` in `apps/deskling/dist`. It uploads nothing else. It needs notary credentials in a keychain profile, stored once:

```sh
xcrun notarytool store-credentials clawd-notary   # the profile keeps its old name --apple-id <your Apple ID> --team-id <your team ID>
```

Set `APP_IDENTITY="Developer ID Application: You (TEAMID)"` to sign with your own identity.

`make publish` then uploads that disk image as a GitHub release for the version in `apps/deskling/VERSION` and updates the Homebrew cask from `scripts/deskling.rb.in`, in one commit to the tap. The first Deskling release also renames the cask from `clawd` to `deskling` and records the rename in the tap's `cask_renames.json`, so `brew upgrade` moves existing users across. Pass `NOTES=<file>` for hand-written release notes. The website deploys on its own when `main` changes.

## License

MIT for the code — see [LICENSE](LICENSE). © 2026 Kevin B. Ridgway. The Clawd character and the animation files belong to Anthropic and are not covered by the license.
