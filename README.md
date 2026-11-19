# Clawd 🦀 — Clawd, on your desktop

[![GitHub release](https://img.shields.io/github/v/release/program247365/clawd?style=flat-square)](https://github.com/program247365/clawd/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-555?style=flat-square)](#install)
[![License](https://img.shields.io/github/license/program247365/clawd?style=flat-square)](LICENSE)
[![Homebrew](https://img.shields.io/badge/Homebrew-program247365%2Ftap-FBB040?style=flat-square&logo=homebrew&logoColor=white)](https://github.com/program247365/homebrew-tap)

Clawd is a small menubar app that puts Clawd on your Mac. He walks along the bottom of your screen and stops to fish, juggle, or water a plant. Let him roam and he'll pop up anywhere on the screen to do it there. Clicks pass straight through him.

Clawd is Anthropic's character. This is an unofficial fan project.

See him walk in a browser at [clawd.kbr.sh](https://clawd.kbr.sh).

## Install

| Platform | Install |
| --- | --- |
| macOS 14+ (Apple silicon or Intel) | `brew install --cask program247365/tap/clawd` |

The [DMG](https://github.com/program247365/clawd/releases/latest/download/Clawd.dmg) is available as a direct install: open it and drag Clawd to Applications. Windows and Linux are planned.

## Quick start

```sh
open -a Clawd
```

Clawd appears at the bottom of the screen and his icon appears in the menubar. From the menu you can hide him, pick Small, Medium, or Large, turn on Launch at Login, and open Settings to let him roam.

## What Clawd does

- Walks along the bottom edge of the screen, on top of the Dock when it is there.
- Stops to perform one of his acts, and plays every act once before repeating any.
- Drops in from the top of the screen under a spotlight when the app launches.
- Stays at the bottom by default. Choose "Let Clawd roam!" in Settings and about one time in four he pops out and reappears somewhere else to perform.
- Visits your lock screen if you turn on "Make Clawd visit your lock screen" in Settings. This uses private macOS window-server functions, so it is off by default and a macOS update could break it. It is confirmed on macOS 27 and untested on earlier versions.
- Stays above your windows but never takes a click, a scroll, or focus.
- Stays out of fullscreen apps, the Dock, and Cmd-Tab.

## Development

The repo holds two apps:

| Path | What |
| --- | --- |
| `apps/clawd` | the Mac app (Swift package) |
| `apps/website` | the clawd.kbr.sh site and the animation files |

Building needs a Swift 6 toolchain (Xcode 16 or newer). From the repository root:

```sh
make check
```

`make check` verifies every act on the site has its animation and thumbnail, builds the app, and runs the tests, including one that renders every animation.

To run a local build of the app:

```sh
make -C apps/clawd run
```

That builds `apps/clawd/dist/Clawd.app` for your Mac with an ad-hoc signature. `make -C apps/clawd icons` regenerates the icons from the art.

### Releasing

`make -C apps/clawd release` builds a universal app, signs it with a Developer ID, notarizes it with Apple, and leaves `Clawd.dmg` in `apps/clawd/dist`. It uploads nothing else. It needs notary credentials in a keychain profile, stored once:

```sh
xcrun notarytool store-credentials clawd-notary --apple-id <your Apple ID> --team-id <your team ID>
```

Set `APP_IDENTITY="Developer ID Application: You (TEAMID)"` to sign with your own identity.

## License

MIT for the code — see [LICENSE](LICENSE). © 2026 Kevin B. Ridgway. The Clawd character and the animation files belong to Anthropic and are not covered by the license.
