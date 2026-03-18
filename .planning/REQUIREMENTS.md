# Requirements: articles

**Defined:** 2026-03-18
**Core Value:** Read web articles distraction-free in the terminal — paste a URL and start reading.

## v1 Requirements

### Extraction

- [ ] **EXTR-01**: User can provide a URL and get the web page extracted as markdown via w3m
- [ ] **EXTR-02**: User sees a loading indicator while a page is being fetched and extracted

### Display

- [ ] **DISP-01**: User can read extracted article with rendered markdown formatting (headers, bold, links)
- [ ] **DISP-02**: TUI uses a cappuccino/mocha color theme (warm browns, creams, soft accents)

### Navigation

- [ ] **NAV-01**: User can scroll article content up and down with arrow keys
- [ ] **NAV-02**: User can page up and page down through the article

### Input

- [ ] **INPT-01**: User can paste a URL into the TUI and it auto-browses and extracts the article
- [ ] **INPT-02**: User can launch the app with an optional URL argument (`articles [url]`)

## v2 Requirements

### History

- **HIST-01**: User can see a list of recently read articles
- **HIST-02**: User can re-open a previously read article

### Multi-article

- **MULT-01**: User can have multiple articles open and switch between them

## Out of Scope

| Feature | Reason |
|---------|--------|
| Bookmarking | Keep v1 as a pure reader |
| Offline caching | Read once, move on |
| Custom CSS / per-site rules | w3m handles extraction uniformly |
| Browser rendering (headless Chrome) | w3m is simpler and sufficient |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXTR-01 | — | Pending |
| EXTR-02 | — | Pending |
| DISP-01 | — | Pending |
| DISP-02 | — | Pending |
| NAV-01 | — | Pending |
| NAV-02 | — | Pending |
| INPT-01 | — | Pending |
| INPT-02 | — | Pending |

**Coverage:**
- v1 requirements: 8 total
- Mapped to phases: 0
- Unmapped: 8 ⚠️

---
*Requirements defined: 2026-03-18*
*Last updated: 2026-03-18 after initial definition*
