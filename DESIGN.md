---
name: Clawd
description: Clawd, on your desktop.
colors:
  clawd: "#d97757"
  clawd-deep: "#a8502f"
  desk: "#1d5a66"
  desk-deep: "#174a54"
  ink: "#141413"
  ink-soft: "#4a504f"
  paper: "#ffffff"
  chrome: "#e9eeee"
  line: "#d5dddd"
  wash: "#eef3f3"
  wash-selected: "#e3ecec"
  about-ground: "#f3f5f5"
  term: "#10292e"
  term-text: "#e6f2f3"
  term-prompt: "#7fb3bd"
  term-key: "#24505a"
  term-key-hover: "#2f6772"
  menubar-glass: "rgba(238, 244, 244, 0.82)"
  menu-glass: "rgba(246, 249, 249, 0.96)"
  dock-glass: "rgba(13, 38, 44, 0.62)"
  light-close: "#ff5f57"
  light-minimize: "#febc2e"
  light-zoom: "#28c840"
typography:
  display:
    fontFamily: "'Jersey 15', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "clamp(3rem, min(9.4vw, 12vh), 6rem)"
    fontWeight: 400
    lineHeight: 0.88
    letterSpacing: "0"
  lede:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "clamp(1.125rem, 2.2vw, 1.375rem)"
    fontWeight: 400
    lineHeight: 1.45
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.55
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 600
    lineHeight: 1.2
  button:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "1.1875rem"
    fontWeight: 600
    lineHeight: 1.2
  note:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.55
  chrome:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1
  caption:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.2
  mono:
    fontFamily: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  pixel: "0"
  chip: "5px"
  key: "8px"
  menu: "9px"
  tile: "10px"
  control: "12px"
  window: "14px"
  dock: "20px"
spacing:
  hair: "0.25rem"
  xs: "0.5rem"
  sm: "0.75rem"
  md: "1rem"
  lg: "1.25rem"
  xl: "1.5rem"
  menubar: "2rem"
  titlebar: "2.375rem"
  window-pad: "clamp(1.25rem, min(4.5vw, 5vh), 3.25rem)"
  window-gap: "clamp(2rem, 5vw, 3.5rem)"
  desk-gutter: "clamp(0.875rem, 4vw, 2.5rem)"
components:
  window:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.window}"
    padding: "{spacing.window-pad}"
    width: "min(100%, 58rem)"
  titlebar:
    backgroundColor: "{colors.chrome}"
    textColor: "{colors.ink-soft}"
    height: "{spacing.titlebar}"
    padding: "0 0.875rem"
  button-download:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    typography: "{typography.button}"
    rounded: "{rounded.control}"
    padding: "0.75rem 1.5rem"
  button-download-hover:
    backgroundColor: "{colors.clawd-deep}"
    textColor: "{colors.paper}"
  command-well:
    backgroundColor: "{colors.term}"
    textColor: "{colors.term-text}"
    typography: "{typography.mono}"
    rounded: "{rounded.control}"
    padding: "0.375rem 0.375rem 0.375rem 1rem"
  button-copy:
    backgroundColor: "{colors.term-key}"
    textColor: "{colors.term-text}"
    rounded: "{rounded.key}"
    padding: "0.5rem 0.875rem"
  button-copy-hover:
    backgroundColor: "{colors.term-key-hover}"
  button-copy-copied:
    backgroundColor: "{colors.clawd}"
    textColor: "{colors.ink}"
  menubar:
    backgroundColor: "{colors.menubar-glass}"
    textColor: "{colors.ink}"
    typography: "{typography.chrome}"
    height: "{spacing.menubar}"
    padding: "0 0.875rem"
  menubar-item:
    textColor: "{colors.ink}"
    rounded: "{rounded.chip}"
    height: "1.5rem"
    padding: "0 0.5rem"
  badge-unofficial:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.chip}"
    padding: "0.1875rem 0.5rem"
  menu-panel:
    backgroundColor: "{colors.menu-glass}"
    textColor: "{colors.ink}"
    typography: "{typography.chrome}"
    rounded: "{rounded.menu}"
    padding: "0.3125rem"
  menu-item-hover:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.chip}"
  act-tile:
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.tile}"
    padding: "0.5rem 0.25rem 0.625rem"
  act-tile-hover:
    backgroundColor: "{colors.wash}"
  act-tile-selected:
    backgroundColor: "{colors.wash-selected}"
  act-label-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.chip}"
    padding: "0.125rem 0.4375rem"
  about-card:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "1.375rem 1rem 1.25rem"
  about-row:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    padding: "0.6875rem 1rem"
  about-row-hover:
    backgroundColor: "{colors.wash}"
  dock:
    backgroundColor: "{colors.dock-glass}"
    rounded: "{rounded.dock}"
    padding: "{spacing.xs}"
---

# Design System: Clawd

## Overview

**Creative North Star: "The Desk"**

The page is a Mac desktop. A deep blue-green desk carries a faint tile of tiny Clawds, white windows sit on it where someone left them, a glass menubar runs across the top and a Dock sits at the bottom. Clawd himself walks along the bottom edge of the real browser window, in front of everything, and clicks pass straight through him. The page does not describe the app; it behaves like it.

Everything that is not Clawd is quiet desktop furniture: platform sans, ink controls, grey title bars, one soft shadow per window. That restraint is what lets one orange pixel character and one pixel-face headline carry the whole personality. Density is low; each window holds one job, and the first screen is a single window with open desk under it for Clawd to walk on.

The furniture is real, not costume. The menubar item is the app's own menu and it works on the page's Clawd; the Acts window is a Finder-style icon grid whose items make him perform; the About window is laid out like the app's About window. A piece of desktop chrome earns its place by doing what it would do on a Mac.

**Key Characteristics:**
- One world, literal: desk, windows, menubar, Dock, and a character who lives on the bottom edge.
- Clawd is the only saturated thing on screen and the only thing that moves on his own.
- Ink-on-paper controls; inversion to ink is the selection language.
- Two voices of type: one pixel face for the headline, the platform sans for everything else.
- Glass for the menubar and Dock, one soft teal-tinted shadow for windows, nothing lifted inside a window.
- Works with no animation library (a static pixel Clawd stays) and under reduced motion (he stands still).

## Colors

A cool, low-chroma teal desktop with white paper and near-black ink, against which a single warm orange belongs to Clawd.

### Primary
- **Clawd Orange** (#d97757): his body, set by his own art. Beyond him it appears only on things that are his or that confirm an act: the square pixel bullets in the Read Me list, text selection, and the Copy key while it reads "Copied".
- **Clawd Shadow Orange** (#a8502f): the hover state of the download button, and nowhere else. It is the deep step that keeps white text legible where the body orange would not.

### Secondary
- **Desk Teal** (#1d5a66): the desktop itself and the browser theme colour. Always carries the Clawd tile (white at 5.5% opacity, a 120 by 96 tile holding two Clawds cut from his 4px grid).
- **Deep Desk** (#174a54): the scrollbar track; the darker step of the desk.

### Tertiary
- **Terminal Well** (#10292e): the ground of the Homebrew command, a dark teal rather than black so it belongs to the desk.
- **Terminal Text** (#e6f2f3): command text, Copy key label, and the running dot under the first Dock icon.
- **Prompt Teal** (#7fb3bd): the `$` prompt and the scrollbar thumb.
- **Terminal Key** (#24505a) and **Terminal Key Hover** (#2f6772): the Copy key at rest and on hover.

### Neutral
- **Ink** (#141413): all text on paper, the download button, the unofficial badge, selected labels, menu hover rows, the outer focus ring. It is also the colour of Clawd's eyes.
- **Soft Ink** (#4a504f): secondary text only: title bar titles, requirements, hints, captions, the menubar status, the external-link arrow.
- **Paper** (#ffffff): window bodies and cards.
- **Chrome Grey** (#e9eeee): title bars.
- **Hairline** (#d5dddd): 1px dividers inside windows and menus.
- **Wash** (#eef3f3) and **Selected Wash** (#e3ecec): hover and selected grounds for icon tiles and list rows.
- **About Ground** (#f3f5f5): the body of the About window, behind its white cards.
- **Menubar Glass**, **Menu Glass**, **Dock Glass**: the three translucent plates (values in the frontmatter). The menubar and menus are light glass; the Dock is dark glass so its plate holds over white windows as well as over the desk.
- **Traffic lights** (#ff5f57, #febc2e, #28c840): title bar decoration only, never a status colour.

### Named Rules
**The Clawd Orange Rule.** Orange is Clawd. It may mark something that is his (a pixel bullet, a selection, a "Copied" confirmation) but never a resting control, a link, a heading, a border, or a background. If a second orange thing competes with him for the eye, remove it.

**The Ink Inversion Rule.** Selection and emphasis are ink with paper text: the selected act label, the hovered menu row, the unofficial badge, the download button. Do not introduce a second selection colour.

**The Tinted Neutral Rule.** Every grey, glass and shadow leans toward the desk's teal. Pure neutral grey and pure black do not appear; the darkest value is Ink.

## Typography

**Display Font:** Jersey 15 (self-hosted woff2, falling back to the platform sans while it swaps in)
**Body Font:** the platform sans (-apple-system, BlinkMacSystemFont, "Helvetica Neue", "Segoe UI", system-ui)
**Label/Mono Font:** the platform monospace (ui-monospace, "SF Mono", Menlo, Consolas)

**Character:** A chunky pixel face for the one line that names the thing, drawn on the same kind of grid Clawd is. Everything else is the operating system's own sans, because the chrome is a desktop and that is the desktop's voice.

### Hierarchy
- **Display** (400, clamp(3rem, min(9.4vw, 12vh), 6rem), line-height 0.88, tracking 0, balanced wrap): the headline in the hero window. Height-aware so it holds the first screen on short displays.
- **Lede** (400, clamp(1.125rem, 2.2vw, 1.375rem), 1.45, pretty wrap, max 42rem): the paragraph under the headline.
- **Body** (400, 1.0625rem, 1.55): window prose and list items. Line length capped at 34rem in the Read Me window.
- **Title** (600, 1.0625rem, 1.2): the app name in the About window.
- **Button** (600, 1.1875rem, 1.2): the download button label, with a 0.8125rem / 500 second line at 85% opacity.
- **Note** (400, 0.9375rem, Soft Ink): requirements and the hint above the icon grid.
- **Chrome** (400, 0.875rem, line-height 1): menubar items, menu rows, the Copy key (600), About rows. The app name in the menubar is 700; the unofficial badge is 600. Clock, status and counts use tabular numerals.
- **Caption** (400, 0.8125rem, 1.2): act labels, About captions; title bar titles use it at 600. Menu group labels step down to 0.75rem.
- **Mono** (400, 0.9375rem, 1.4): shell commands only.

### Named Rules
**The Two Voices Rule.** Jersey 15 is for the headline. It never sets body text, chrome, labels or buttons; a second pixel-face line on a surface must be a headline of the same rank, not a decoration.

**The Desktop Voice Rule.** Chrome and body use the platform sans at the weights a Mac uses (400, 600, 700 for the app name). Do not swap in a brand sans; the system face is the material here. Sentence case throughout, and no uppercase tracked labels.

## Layout

The desk is one centred grid column with a gutter of clamp(0.875rem, 4vw, 2.5rem) and a gap of clamp(2rem, 5vw, 3.5rem) between windows. Windows have fixed maximum widths by job: the main window 58rem, a reading window 40rem, the About window 21.25rem. Window bodies pad by clamp(1.25rem, min(4.5vw, 5vh), 3.25rem); the icon-grid window pads tighter at clamp(1rem, 3vw, 1.75rem).

The first screen is the hero window alone, vertically centred in a row that is at least the small viewport height minus the menubar, with desk left open beneath it (45% of Clawd's height plus 2.5rem) for the Dock and for him to walk. The page ends with half of Clawd's height plus 7.5rem of open desk so he never covers the last window.

Inside a window the rhythm is a 0.25rem grid: 0.25, 0.5, 0.75, 1, 1.25, 1.5rem, with larger gaps scaled by viewport height so the hero holds on short displays. The Acts grid is `auto-fill` columns of at least 7.25rem (5.75rem on small screens) with a 0.25rem gap.

Stacking, bottom to top: windows, Dock (20), Clawd (30), menubar (40), menu panel (50), skip link (60). Clawd passes in front of windows and the Dock and behind the menubar.

Responsive behaviour:
- **From 64rem up**, windows below the hero leave the centre column: the Acts and About windows hang from the left edge of a 66rem band, the Read Me window from the right edge of a 62rem band, and they overlap vertically (the Read Me window pulls up 1.5rem, the About window 9rem to sit beside it with clear desk between).
- **Below 48rem**, the Dock is removed, the menubar keeps only the app name, the unofficial badge and the Clawd menu, the install controls stack, the command wraps instead of scrolling, the hero row stops reserving a full screen, and Clawd scales to 55%.

**The Left-Where-It-Was Rule.** On wide screens windows are placed, not stacked: offset left and right with a slight overlap in the vertical, as if dragged there. Only the hero window is centred. Windows never touch or cover each other's text.

**The Open Floor Rule.** The bottom edge belongs to Clawd. Every surface reserves desk beneath its content in proportion to his height, and nothing but the Dock is pinned there.

## Elevation & Depth

Hybrid, and sparse. Windows float on the desk with one soft, downward shadow tinted the desk's own dark teal. The menubar, menus and Dock are glass: translucent plates with an 18px backdrop blur (saturation 1.4 on the menubar and Dock) and no shadow of their own, except the open menu, which casts a smaller shadow. Inside a window everything is flat; depth there is tonal (paper, wash, selected wash, about ground) and hairlines.

### Shadow Vocabulary
- **Window** (`box-shadow: 0 28px 70px -18px rgba(6, 28, 34, 0.6)`): every window, and only windows.
- **Menu** (`box-shadow: 0 14px 36px -8px rgba(6, 28, 34, 0.5)`): the open menu panel.
- **Focus ring** (`outline: 2px solid #fff; outline-offset: 0; box-shadow: 0 0 0 5px #141413`): not elevation, but it lives in the same property; see Components.

### Named Rules
**The One Shadow Rule.** A window gets the window shadow and nothing inside it gets any. Buttons, cards, tiles and rows are flat at rest and on hover; hover changes ground colour or lifts by transform, never by shadow.

**The Glass Is Chrome Rule.** Backdrop blur is for the system plates pinned to the viewport: menubar, menu, Dock. Windows and their contents are opaque.

## Shapes

Two form languages that never mix. Desktop furniture is soft and concentric: windows 14px, the Dock plate 20px, controls and cards 12px, the icon tile 10px, the menu panel 9px, keys 8px, and small chips (menubar items, menu rows, labels, the badge) 5px. Inner radii are always smaller than the container they sit in. Traffic lights are 0.75rem circles.

Clawd and everything cut from him is square: his fallback figure, the menubar glyph, the desk tile and the 0.5625rem list bullet are all drawn on his pixel grid with crisp edges and no radius. Act thumbnails render with `image-rendering: pixelated`.

Borders are rare: 1px Hairline dividers between rows and above the unofficial line. Windows, cards and controls have no outline stroke; their edge is the colour change against the desk or paper.

**The Square Pixel Rule.** Anything derived from Clawd keeps hard square pixels: no rounding, no anti-aliased scaling, no smoothing. Anything that is desktop furniture is rounded. Nothing is both.

## Components

### Buttons
Plain, heavy and few: one ink button per window at most.
- **Download:** Ink ground, Paper text, softly rounded (12px), padding 0.75rem 1.5rem, a two-line label (action, then a smaller facts line). Left-aligned text.
- **Hover:** ground shifts to Clawd Shadow Orange and the button rises 1px (0.2s, the system ease).
- **Copy key:** sits inside the command well; Terminal Key ground, Terminal Text label, 8px radius. Hover lightens the ground. For two seconds after a successful copy it turns Clawd Orange with Ink text and reads "Copied".
- **Focus (all interactive elements):** a 2px white ring inside a 3px visible ink ring (drawn as a 5px ink spread under the white outline), so it reads on paper, on the desk and on dark controls alike. Where a container clips its corners, the ring is drawn inside the row instead (3px inset ink).

### Command well
The Homebrew command on a Terminal Well ground (12px radius), platform monospace, with a Prompt Teal `$` generated before it and the Copy key at its right. The command scrolls horizontally without a scrollbar on wide screens and wraps on small ones.

### Windows
- **Corner Style:** 14px, clipped.
- **Background:** Paper body under a Chrome Grey title bar (2.375rem tall) holding three traffic lights at left, a centred title in Soft Ink (0.8125rem, 600), and an optional right-aligned count in regular weight with tabular numerals.
- **Shadow Strategy:** the Window shadow; see Elevation.
- **Border:** none.
- **Internal Padding:** the window-pad scale; tighter for icon grids, 1.25rem for the About window.
- Each window is a labelled section; its title bar names it.

### Icon tiles (Acts)
A Finder icon view. Each tile is a button: a pixelated thumbnail (max 8.25rem) over a caption label, 10px radius, no ground at rest. Hover adds Wash. The act Clawd is currently performing shows Selected Wash with its label inverted to ink in a 5px chip; the selection follows him, whether the visitor chose the act or he did. If the animations did not load, the tiles are disabled and the hint says so.

### About window
A narrow window on the About Ground: a white card (12px) with the 88px app icon, the name as a title and the tagline as a caption; then a white grouped list (12px, clipped) of full-width rows separated by hairlines, each ending in a small up-and-right arrow because it opens elsewhere; then a centred caption carrying the unofficial line.

### Lists
Read Me facts are a single-column list with a 0.625rem gap; each item is marked by one square Clawd Orange pixel (0.5625rem) instead of a bullet.

### Navigation
- **Menubar:** fixed, 2rem tall, light glass. Left: the app name in bold, then section links. Right: the unofficial badge (ink chip, always visible, at every width), the name of what Clawd is doing right now in Soft Ink, the Clawd menu, and a clock. Items are 1.5rem tall chips (5px) that take a 10% ink wash on hover or while their menu is open.
- **Clawd menu:** the menubar glyph is Clawd's silhouette in the current text colour. It opens a light-glass panel (9px, at least 13rem wide) with Hide/Show Clawd, a Size group (Small, Medium, Large) between hairlines with a drawn checkmark on the current size, and About. Rows invert to ink on hover. Escape and outside clicks close it.
- **Dock:** fixed, centred, 0.625rem above the bottom edge; a dark-glass plate (20px) holding 3.25rem icons with a 0.5rem gap. The first icon is the app icon and has a running dot beneath it. Icons rise 6px and grow to 108% on hover or focus (0.25s). The other icons are flat two- or three-colour drawings (folder, document, code) at the same size. Removed below 48rem.

### Clawd
The signature component. A fixed, full-colour animated figure pinned to the bottom-left of the viewport and moved by transform, with `pointer-events: none` so every click, scroll and keystroke goes to what is under him.
- **Size:** set by the Size menu as an animation canvas of 380px (Small), 560px (Medium, the default) or 760px (Large), capped at 96vw and 62vh; aspect 2750:1850. His body is about 41% of the canvas, so Medium is roughly a 230px Clawd.
- **Routine:** walk to a stop at least a third of the floor away, perform an act, repeat; about one time in four he pops out, reappears somewhere above the floor to perform, and pops back. He walks at about 0.39 of his own canvas width per second and flips to face the way he is going. Short acts play twice.
- **Pop:** opacity to 0 and scale to 0.6 over 0.15s, out and in.
- **States:** hidden from the menu; a static pixel Clawd (drawn in the markup at body size) shows until the animation draws and stays if it never loads; under reduced motion he stands still, and choosing an act shows a still of it for four seconds.
- The menubar status names his current act, and the matching Acts tile is selected.

### Motion
One ease for interface transitions, `cubic-bezier(0.16, 1, 0.3, 1)`, at 0.15s to 0.25s, on ground colour and transform only. Anchor scrolling is smooth and stops clear of the menubar. Under reduced motion all transitions collapse and scrolling is instant. Nothing but Clawd animates unprompted.

## Do's and Don'ts

### Do:
- **Do** build new surfaces as desktop furniture: a window with a title bar and traffic lights, a menu, a Dock item. Give each window one job and name it in its title bar.
- **Do** make chrome behave like the thing it imitates. A menu that looks like the app's menu must work like it.
- **Do** keep controls Ink (#141413) on Paper, and use ink inversion for selection.
- **Do** keep Clawd in front of windows and the Dock, behind the menubar, with clicks passing through him, and reserve open desk at the bottom of every surface in proportion to his height.
- **Do** keep the unofficial badge in the menubar at every width and the unofficial line beside the install action.
- **Do** offset windows left and right on screens from 64rem up, with clear desk between them.
- **Do** tint greys, glass and shadows toward the desk teal, and use the window shadow (`0 28px 70px -18px rgba(6, 28, 34, 0.6)`) unchanged.
- **Do** keep the white-inside-ink focus ring on every interactive element, drawn inset where a container clips.
- **Do** keep a still Clawd for reduced motion and a static one for when the animation cannot load; text and the install controls never depend on him.

### Don't:
- **Don't** use Clawd Orange (#d97757) for a resting button, link, heading, border or background. It is his.
- **Don't** set anything but a headline in Jersey 15, and don't replace the platform sans with a brand face.
- **Don't** put shadows on anything inside a window, or blur behind anything that is not a viewport-pinned plate.
- **Don't** round anything cut from Clawd's pixels, or smooth his thumbnails when scaling them.
- **Don't** give Clawd a hit target, a hover state, or any way to block what is beneath him.
- **Don't** let anything other than Clawd move on its own; interface motion answers a hover, a focus or a click.
- **Don't** use the traffic-light colours to mean anything; they are title bar decoration.
- **Don't** centre every window in one column on wide screens; that turns the desk back into a page.
- **Don't** set text directly on the bare desk; Ink on Desk Teal is about 2.4:1. Text lives in a window, on a glass plate, or in the terminal well.
- **Don't** add stroke outlines to windows, cards or buttons; edges are colour changes, dividers are 1px Hairline.
