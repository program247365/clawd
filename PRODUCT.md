# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static HTML, CSS, and JavaScript with no framework or build step, in `apps/website/`, deployed by Vercel from `main`. Confirmed by Kevin in the approved design (`docs/superpowers/specs/2026-11-18-clawd-mac-app-design.md`).

## Users

Claude Code users: developers who already know Clawd from Claude Code and Anthropic's blog. They arrive from a shared link, on a Mac, and decide in a few seconds whether to put him on their desktop.

## Product Purpose

Deskling (formerly Clawd) is a free, open-source Mac menubar app that puts a pixel character on the desktop: Clawd, Octo, Minx, Sol, or Luna, picked on a character-select screen. They walk along the bottom of the screen and stop to perform their acts; with "Let them roam!" in Settings they sometimes teleport to perform somewhere else. With the Claude Code plugin or Codex hooks connected, they act out what the agent is doing and come and wave when it needs you. deskling.kbr.sh is where people install it (clawd.kbr.sh redirects there). Success for the site is an install: a download of the DMG or a `brew install`.

## Positioning

The real Clawd, with his original animations, walking on your actual desktop rather than in a browser tab, in a small native app that never takes a click.

## Operating Context

- Visitors already know who Clawd is; the page does not need to introduce him.
- The app lives in the menubar: Hide/Show, Small/Medium/Large, Launch at Login, Settings, About, Quit.
- On launch he drops in from the top of the screen under a spotlight, lands, waves, and then starts walking.
- Install is by Homebrew cask (`brew install --cask program247365/tap/clawd`) or a notarized DMG.
- The site also runs the same walk-and-perform loop live in the page.

## Capabilities and Constraints

- macOS 14 or later, Apple silicon and Intel. Windows and Linux are planned, not available.
- Clicks, scrolls, and typing pass through him. He stays out of native fullscreen apps, the Dock, and Cmd-Tab.
- Measured footprint: 13 to 17MB of memory at rest, peaking near 25MB while an act loads, and about 4% of one CPU core. Version 0.2.0 sat at 40MB: only about 6MB was in use, the rest was freed memory the default allocator kept counted against the app. The app now starts with the allocator's space-efficient mode (`MallocSpaceEfficient`, set in `Info.plist`), which hands that memory back.
- 37 animations, plain Lottie vector files at 12fps, in `apps/website/assets/`.
- The download control links to `https://github.com/program247365/clawd/releases/latest/download/Clawd.dmg`. The Homebrew cask `program247365/tap/clawd` is published.
- An optional setting lets him appear on the lock screen. It relies on private macOS functions, is off by default, and disables itself if a macOS update removes them. Confirmed on macOS 27.0.1 only; untested on macOS 14 to 26.
- The page must work at 375px wide, show a still Clawd under reduced motion, and still show its text and download control if the animation library fails to load.

## Brand Commitments

- Name: Deskling. Tagline: "Little friends for your desktop." Clawd is one of its characters, not the product name.
- Voice: a small personal side project. First person, playful, short. One person made it for fun; no company is behind it.
- Must appear verbatim: "Clawd is Anthropic's character. This is an unofficial fan project."
- The unofficial status must be clear and prominent (Kevin's instruction), near the top of the page and next to the install action, not only in the footer. Nothing on the page may read as coming from Anthropic.
- Credit: "by Kevin B. Ridgway", linking to https://kbr.sh?source=deskling-site. No company name and no email address.
- Source: https://github.com/program247365/clawd
- Clawd's own art sets his colors: body orange `#d97757`, eyes `#141413`. The app icon puts him on cream `#faf9f5`.

## Evidence on Hand

- The live demo: `apps/website/index.html`, which fetches each animation from `apps/website/assets/` when it is needed.
- The app icon and menubar icon: `apps/clawd/Resources/`.
- A contact sheet of all 37 animations can be regenerated with `make -C apps/clawd check` (`apps/clawd/.build/contact-sheet.png`).
- No testimonials, download counts, press, or screenshots of the app on a real desktop exist yet. Do not invent any.

## Product Principles

1. Show him, don't describe him. The demo does the persuading.
2. Install is the one action. Everything else is quieter.
3. Honest about what it is: a fan project, free, one person's work, Anthropic's character.
4. Never in the way: the app does not interrupt work, and the page does not interrupt the visitor.

## Accessibility & Inclusion

Keyboard reachable with visible focus; honors `prefers-reduced-motion`; no information carried by motion alone.
