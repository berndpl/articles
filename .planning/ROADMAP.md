# Roadmap: articles

## Overview

### v1.0 — Core Reader (Complete)

Two phases to ship a working terminal article reader. Phase 1 establishes the extraction pipeline and CLI entry point — a working `articles` command that fetches and dumps a URL as markdown. Phase 2 wraps that pipeline in a full TUI: styled rendering, cappuccino theme, keyboard navigation, paste-to-read, and loading feedback.

### v2.0 — History & Polish

Two phases to polish the reading experience and add history. Phase 3 migrates to the official Catppuccin Mocha theme, removes custom theme code, hides the scrollbar, and fixes slow startup via lazy imports — quick wins that establish the visual and performance baseline. Phase 4 adds article history: a persistent list of recently read articles on the welcome screen with the ability to re-open them.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - CLI entry point and w3m extraction pipeline (completed 2026-03-18)
- [x] **Phase 2: Reader** - Full TUI reading experience with theme, navigation, and paste input (completed)
- [ ] **Phase 3: Theme & Performance** - Catppuccin Mocha theme, scrollbar cleanup, fast startup
- [ ] **Phase 4: History** - Reading history with persistent storage and re-open from welcome screen

## Phase Details

### Phase 1: Foundation
**Goal**: User can invoke `articles [url]` from the terminal and get a URL's content extracted as markdown
**Depends on**: Nothing (first phase)
**Requirements**: EXTR-01, INPT-02
**Success Criteria** (what must be TRUE):
  1. Running `articles https://example.com` in the terminal outputs or displays extracted article content
  2. The `articles` command is available as a CLI executable (installable via pip or direct invocation)
  3. w3m is invoked under the hood to fetch and convert the page; no headless browser is required
**Plans**: 1 plan

Plans:
- [ ] 01-01-PLAN.md — Project scaffold, w3m extractor, and CLI entry point

### Phase 2: Reader
**Goal**: User can read any web article distraction-free in a Textual TUI with keyboard navigation, cappuccino theme, paste-to-read, and loading feedback
**Depends on**: Phase 1
**Requirements**: DISP-01, DISP-02, NAV-01, NAV-02, EXTR-02, INPT-01
**Success Criteria** (what must be TRUE):
  1. Article content renders with styled markdown formatting (headers visually distinct, bold text bold, links visible) inside the TUI
  2. The TUI uses a warm cappuccino/mocha color palette — warm browns and creams for background and text
  3. User can scroll up and down through an article using arrow keys without leaving the TUI
  4. User can page up and page down through long articles
  5. User can paste a URL directly into the TUI and the article loads automatically without any extra commands
  6. A loading indicator appears while a URL is being fetched and extracted, and disappears when rendering is complete
**Plans**: 2 plans

Plans:
- [ ] 02-01-PLAN.md — Markdown extraction (trafilatura) and cappuccino theme definition
- [ ] 02-02-PLAN.md — Textual TUI application, CLI wiring, and visual verification

### Phase 3: Theme & Performance
**Goal**: App uses the official Catppuccin Mocha palette with a clean scrollbar-free UI and launches in under 500ms
**Depends on**: Phase 2
**Requirements**: THEME-01, THEME-02, THEME-03, PERF-01
**Success Criteria** (what must be TRUE):
  1. TUI renders with official Catppuccin Mocha colors (dark base, pastel accents) instead of custom cappuccino palette
  2. No custom theme code remains in the codebase (`theme.py` deleted or emptied)
  3. Scrollbar is not visible during article reading
  4. App launches and shows the welcome/input screen in under 500ms
**Plans**: TBD

### Phase 4: History
**Goal**: Users can browse and re-open previously read articles from the launch screen
**Depends on**: Phase 3
**Requirements**: HIST-01, HIST-02, HIST-03
**Success Criteria** (what must be TRUE):
  1. Welcome screen shows a list of previously read articles (title and/or URL)
  2. User can select an article from the history list and it re-opens in the reader
  3. History persists across app restarts — articles read in one session appear in the next
  4. First launch with no history shows a clean welcome screen without errors
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 1/1 | Complete | 2026-03-18 |
| 2. Reader | 2/2 | Complete | 2026-03-19 |
| 3. Theme & Performance | 0/? | Not started | - |
| 4. History | 0/? | Not started | - |
