# articles

## What This Is

A terminal-based article reader that extracts web articles into clean, readable markdown. Paste or provide a URL, and `articles` uses trafilatura to fetch and extract the article content as markdown, then renders it in a cozy cappuccino/mocha-themed TUI with keyboard navigation.

## Core Value

Read web articles distraction-free in the terminal — paste a URL and start reading.

## Requirements

### Validated

- [x] Extract web pages to markdown using trafilatura — Validated in Phase 1+2
- [x] Render markdown with styled formatting (headers, bold, links) in TUI — Validated in Phase 2
- [x] Cappuccino/mocha color theme — Validated in Phase 2
- [x] Keyboard shortcuts for scrolling and paging (up/down, page up/down) — Validated in Phase 2
- [x] Accept paste events for URLs — auto-browse and extract on paste — Validated in Phase 2
- [x] Show loading indicator while fetching and extracting — Validated in Phase 2
- [x] CLI executable (`articles`) with optional URL argument — Validated in Phase 1
- [x] Python + Textual stack — Validated in Phase 1

### Active

- [ ] Article reading history — see recently read articles on launch
- [ ] Re-open previous articles from history list
- [x] Catppuccin Mocha theme — switch to official community palette — Validated in Phase 3
- [x] Startup performance — lazy-import trafilatura for fast launch — Validated in Phase 3

### Out of Scope

- Offline caching — read once, move on
- Multiple tabs/windows — single article at a time (deferred from v1)
- Custom CSS or per-site extraction rules

## Context

- Built with Python and the Textual TUI framework for rich terminal rendering
- Uses trafilatura to extract article content as markdown (replaced w3m in Phase 2)
- Textual provides built-in markdown rendering, theming, and input handling
- Target: macOS terminal (bash 3.2+ compatible for any shell scripts)

## Constraints

- **Shell compatibility**: Any bash scripts must work on bash 3.2+ (Intel Mac baseline)
- **Platform**: macOS primary, standard terminal emulators

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Python + Textual | Rich markdown rendering built-in, easy theming, rapid development | ✓ Validated |
| trafilatura for extraction | Article-only markdown output (replaced w3m which only produced plain text) | ✓ Validated |
| Single-article view | Keep v1 focused — one URL, one reading experience | ✓ Validated |
| Dark mocha cappuccino theme | Cozy reading experience — dark brown bg, cream text, cinnamon accents | Replaced by Catppuccin Mocha in Phase 3 |
| VerticalScroll + Markdown | MarkdownViewer has can_focus=False bug — VerticalScroll enables arrow key scrolling | ✓ Validated |
| Catppuccin Mocha theme | Official community palette, built-in Textual theme, zero custom theme code | ✓ Validated |
| Lazy-import trafilatura | Eliminates ~518ms startup cost — import only when extract_url() called | ✓ Validated |

## Current Milestone: v2.0 History & Polish

**Goal:** Add reading history, switch to Catppuccin Mocha theme, and fix startup performance.

**Target features:**
- Article history — recently read list on launch screen, re-open previous articles
- Catppuccin Mocha — official community color palette replacing custom cappuccino
- Startup performance — profile and fix slow app launch time

---
*Last updated: 2026-03-19 — Phase 3 complete (Catppuccin Mocha + startup perf)*
