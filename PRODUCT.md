# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Static HTML, CSS, and JavaScript with no framework or build step, in `apps/website/`, deployed by Vercel from `main`. Confirmed by Kevin in the approved design (`docs/superpowers/specs/2026-11-18-clawd-mac-app-design.md`).

## Users

Claude Code users: developers who already know Clawd from Claude Code and Anthropic's blog. They arrive from a shared link, on a Mac, and decide in a few seconds whether to put him on their desktop.

## Product Purpose

Clawd is a free, open-source Mac menubar app that puts Clawd on the desktop. He walks along the bottom of the screen, stops to perform one of his acts, and sometimes teleports to perform somewhere else. clawd.kbr.sh is where people install it. Success for the site is an install: a download of the DMG or a `brew install`.

## Positioning

The real Clawd, with his original animations, walking on your actual desktop rather than in a browser tab, in a small native app that never takes a click.

## Operating Context

- Visitors already know who Clawd is; the page does not need to introduce him.
- The app lives in the menubar: Hide/Show, Small/Medium/Large, Launch at Login, About, Quit.
- Install is by Homebrew cask (`brew install --cask program247365/tap/clawd`) or a notarized DMG.
- The site also runs the same walk-and-perform loop live in the page.

## Capabilities and Constraints

- macOS 14 or later, Apple silicon and Intel. Windows and Linux are planned, not available.
- Clicks, scrolls, and typing pass through him. He stays out of native fullscreen apps, the Dock, and Cmd-Tab.
- Measured footprint: about 18MB of memory and about 4% of one CPU core.
- 37 animations, plain Lottie vector files at 12fps, in `apps/website/assets/`.
- Until the first release is published, the download control is in a "Coming soon" state and is not a link.
- The page must work at 375px wide, show a still Clawd under reduced motion, and still show its text and download control if the animation library fails to load.

## Brand Commitments

- Name: Clawd. Tagline: "Clawd, on your desktop."
- Voice: a small personal side project. First person, playful, short. One person made it for fun; no company is behind it.
- Must appear verbatim: "Clawd is Anthropic's character. This is an unofficial fan project."
- The unofficial status must be clear and prominent (Kevin's instruction), near the top of the page and next to the install action, not only in the footer. Nothing on the page may read as coming from Anthropic.
- Credit: "by Kevin B. Ridgway", linking to https://kbr.sh?source=clawd-site. No company name and no email address.
- Source: https://github.com/program247365/clawd
- Clawd's own art sets his colors: body orange `#d97757`, eyes `#141413`. The app icon puts him on cream `#faf9f5`.

## Evidence on Hand

- The live demo: `apps/website/index.html` and the animation bundle `apps/website/assets/clawd-data.js`.
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
