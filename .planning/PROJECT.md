# articles

## What This Is

A terminal-based article reader that extracts web articles into clean, readable markdown. Paste or provide a URL, and `articles` uses w3m to fetch the page, converts it to markdown, and renders it in a cozy cappuccino/mocha-themed TUI with keyboard navigation.

## Core Value

Read web articles distraction-free in the terminal — paste a URL and start reading.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Extract web pages to markdown using w3m
- [ ] Render markdown with styled formatting (headers, bold, links) in TUI
- [ ] Cappuccino/mocha color theme
- [ ] Keyboard shortcuts for scrolling and paging (up/down, page up/down)
- [ ] Accept paste events for URLs — auto-browse and extract on paste
- [ ] Show loading indicator while fetching and extracting
- [ ] CLI executable (`articles`) with optional URL argument
- [ ] Python + Textual stack

### Out of Scope

- Bookmarking or history — keep it a pure reader for now
- Offline caching — read once, move on
- Multiple tabs/windows — single article at a time
- Custom CSS or per-site extraction rules — w3m handles it all

## Context

- Built with Python and the Textual TUI framework for rich terminal rendering
- Uses w3m (`w3m -dump`) to extract web content as text, then converts to markdown
- Textual provides built-in markdown rendering, theming, and input handling
- Target: macOS terminal (bash 3.2+ compatible for any shell scripts)

## Constraints

- **Runtime dependency**: w3m must be installed (`brew install w3m`)
- **Shell compatibility**: Any bash scripts must work on bash 3.2+ (Intel Mac baseline)
- **Platform**: macOS primary, standard terminal emulators

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Python + Textual | Rich markdown rendering built-in, easy theming, rapid development | — Pending |
| w3m for extraction | Simple, reliable, no heavy dependencies like headless browsers | — Pending |
| Single-article view | Keep v1 focused — one URL, one reading experience | — Pending |

---
*Last updated: 2026-03-18 after initialization*
