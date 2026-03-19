# Requirements: articles

**Defined:** 2026-03-18
**Core Value:** Read web articles distraction-free in the terminal — paste a URL and start reading.

## v1 Requirements

### Extraction

- [x] **EXTR-01**: User can provide a URL and get the web page extracted as markdown via w3m
- [x] **EXTR-02**: User sees a loading indicator while a page is being fetched and extracted

### Display

- [x] **DISP-01**: User can read extracted article with rendered markdown formatting (headers, bold, links)
- [x] **DISP-02**: TUI uses a cappuccino/mocha color theme (warm browns, creams, soft accents)

### Navigation

- [x] **NAV-01**: User can scroll article content up and down with arrow keys
- [x] **NAV-02**: User can page up and page down through the article

### Input

- [x] **INPT-01**: User can paste a URL into the TUI and it auto-browses and extracts the article
- [x] **INPT-02**: User can launch the app with an optional URL argument (`articles [url]`)

## v2 Requirements

### Theme

- [x] **THEME-01**: TUI uses the official Catppuccin Mocha color palette (built-in Textual theme)
- [x] **THEME-02**: Custom cappuccino theme code (`theme.py`) is removed
- [x] **THEME-03**: Scrollbar is hidden for a cleaner reading experience

### Performance

- [x] **PERF-01**: App startup time is under 500ms (lazy-import trafilatura)

### History

- [x] **HIST-01**: User can see a list of recently read articles on the launch/welcome screen
- [x] **HIST-02**: User can select a previous article from history to re-open it
- [x] **HIST-03**: Reading history persists across app sessions (JSON file storage)

## Future Requirements

### Multi-article

- **MULT-01**: User can have multiple articles open and switch between them

## Out of Scope

| Feature | Reason |
|---------|--------|
| Bookmarking | Keep it a pure reader |
| Offline caching | Read once, move on |
| Custom CSS / per-site rules | trafilatura handles extraction |
| Browser rendering (headless Chrome) | trafilatura is simpler and sufficient |
| Custom header colors for Catppuccin | Accept default Catppuccin Mocha rendering as-is |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXTR-01 | Phase 1 | Complete |
| INPT-02 | Phase 1 | Complete |
| DISP-01 | Phase 2 | Complete |
| DISP-02 | Phase 2 | Complete |
| NAV-01 | Phase 2 | Complete |
| NAV-02 | Phase 2 | Complete |
| EXTR-02 | Phase 2 | Complete |
| INPT-01 | Phase 2 | Complete |
| THEME-01 | Phase 3 | Complete |
| THEME-02 | Phase 3 | Complete |
| THEME-03 | Phase 3 | Complete |
| PERF-01 | Phase 3 | Complete |
| HIST-01 | Phase 4 | Complete |
| HIST-02 | Phase 4 | Complete |
| HIST-03 | Phase 4 | Complete |

**Coverage:**
- v1 requirements: 8 total — all complete
- v2 requirements: 7 total — all mapped
- Mapped to phases: 15/15 ✓
- Unmapped: 0

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-19 — v2.0 requirements mapped to phases*
