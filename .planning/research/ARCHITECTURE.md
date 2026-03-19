# Architecture Research

**Domain:** Terminal article reader — v2.0 integration (history, Catppuccin Mocha, startup performance)
**Researched:** 2025-07-18
**Confidence:** HIGH

## Current Architecture (v1)

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Layer                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  cli.py — main() parses sys.argv, creates ArticlesApp│   │
│  └──────────────────────┬───────────────────────────────┘   │
├─────────────────────────┼───────────────────────────────────┤
│                      TUI Layer                               │
│  ┌──────────────────────┴───────────────────────────────┐   │
│  │  app.py — ArticlesApp(App)                           │   │
│  │    compose(): StatusBar + VerticalScroll>Markdown     │   │
│  │    on_paste(): URL detection → load_article()        │   │
│  │    load_article(): @work thread → extract + render   │   │
│  └───────────┬──────────────────────┬───────────────────┘   │
├──────────────┼──────────────────────┼───────────────────────┤
│         Extraction              Theme                        │
│  ┌───────────┴──────┐   ┌───────────┴──────┐               │
│  │  extractor.py    │   │  theme.py        │               │
│  │  extract_url()   │   │  CAPPUCCINO      │               │
│  │  → trafilatura   │   │  Theme constant  │               │
│  └──────────────────┘   └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Current File Map

| File | Lines | Responsibility |
|------|-------|----------------|
| `src/articles/cli.py` | 21 | Entry point, argv parsing, app launch |
| `src/articles/app.py` | 131 | TUI app: compose, paste handling, article loading |
| `src/articles/extractor.py` | 34 | URL → markdown via trafilatura |
| `src/articles/theme.py` | 27 | CAPPUCCINO Theme constant |
| `tests/test_app.py` | 35 | 3 async app tests |
| `tests/test_extractor.py` | 43 | 5 extractor tests |

## v2.0 Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Layer                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  cli.py — main() unchanged                           │   │
│  └──────────────────────┬───────────────────────────────┘   │
├─────────────────────────┼───────────────────────────────────┤
│                      TUI Layer                               │
│  ┌──────────────────────┴───────────────────────────────┐   │
│  │  app.py — ArticlesApp(App)                           │   │
│  │    theme = "catppuccin-mocha" (built-in, no register)│   │
│  │    compose(): StatusBar + VerticalScroll>Markdown     │   │
│  │    on_mount(): show history or welcome or initial URL │   │
│  │    on_paste(): URL detect → load_article()           │   │
│  │    load_article(): @work → extract + render + SAVE   │   │
│  └───────────┬──────────┬──────────────┬────────────────┘   │
├──────────────┼──────────┼──────────────┼────────────────────┤
│         Extraction   History UI     History Data             │
│  ┌───────────┴──┐ ┌────┴────┐  ┌──────┴──────────┐        │
│  │ extractor.py │ │ Inline  │  │  history.py     │        │
│  │ LAZY import  │ │ widget  │  │  HistoryStore   │        │
│  │ trafilatura  │ │ in app  │  │  JSON on disk   │        │
│  └──────────────┘ └─────────┘  │  platformdirs   │        │
│                                └─────────────────┘        │
│         Theme: DELETED (built-in catppuccin-mocha)          │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | New/Modified |
|-----------|----------------|--------------|
| `cli.py` | Entry point, argv parsing, app launch | **Unchanged** |
| `app.py` | TUI app, compose, paste, loading, history display | **Modified** — theme swap, history integration, welcome screen update |
| `extractor.py` | URL → markdown extraction | **Modified** — lazy import of trafilatura |
| `theme.py` | ~~CAPPUCCINO constant~~ | **Deleted** — replaced by built-in theme |
| `history.py` | History storage: add, list, load entries | **New** |

## Integration Details

### 1. Catppuccin Mocha Theme — Simplest Change

**Key finding:** Textual 8.1.1 ships `catppuccin-mocha` as a built-in theme. No custom Theme object or `register_theme()` needed.

**What changes in `app.py`:**

```python
# BEFORE (v1):
from articles.theme import CAPPUCCINO

class ArticlesApp(App):
    def __init__(self, url=None):
        super().__init__()
        self.register_theme(CAPPUCCINO)
        self.theme = "cappuccino"

# AFTER (v2):
# No theme import needed

class ArticlesApp(App):
    def __init__(self, url=None):
        super().__init__()
        self.theme = "catppuccin-mocha"
```

**What gets deleted:**
- `src/articles/theme.py` — entire file
- `from articles.theme import CAPPUCCINO` — import in app.py

**Theme color comparison:**

| Property | Cappuccino (v1) | Catppuccin Mocha (v2) |
|----------|----------------|-----------------------|
| background | `#2C1810` dark mocha | `#181825` dark blue-gray |
| foreground | `#F5DEB3` cream | `#cdd6f4` lavender-white |
| primary | `#D2691E` cinnamon | `#F5C2E7` pink/mauve |
| accent | `#CD853F` burnt orange | `#fab387` peach |
| surface | `#3E2723` brown | `#313244` dark gray |
| panel | `#4E342E` brown | `#45475a` medium gray |

**Markdown header defaults:** The built-in theme provides no `markdown-h1-color` override, so headers default to the theme's `primary` color (`#F5C2E7` pink). The v1 theme explicitly set `markdown-h1-color: #D2691E` (cinnamon). The Catppuccin Mocha defaults are well-designed for reading — no custom overrides needed.

**CSS impact:** The existing app CSS uses `$panel`, `$foreground` — these resolve correctly from the new theme. No CSS changes needed.

**Test impact:** `test_app_has_cappuccino_theme` must be updated to assert `"catppuccin-mocha"`.

### 2. Startup Performance — Lazy Import

**Key finding:** Import profiling shows trafilatura is the dominant startup cost.

| Import | Time | % of Total |
|--------|------|------------|
| `textual` (all widgets) | ~360ms | 40% |
| `trafilatura` | ~530ms | **60%** |
| **Total** | **~890ms** | 100% |

Textual imports are unavoidable (needed to define the App class). But trafilatura is only needed when `load_article()` is called — never at startup.

**What changes in `extractor.py`:**

```python
# BEFORE (v1):
import trafilatura

def extract_url(url):
    downloaded = trafilatura.fetch_url(url)
    ...

# AFTER (v2):
def extract_url(url):
    import trafilatura  # Lazy import — only when article is loaded
    downloaded = trafilatura.fetch_url(url)
    ...
```

**Impact:** Startup drops from ~890ms to ~360ms (Textual only). trafilatura's ~530ms cost shifts to first article load, which already shows a "Fetching..." status bar — the user expects a delay there.

**No other files change.** The lazy import is contained entirely within `extractor.py`.

**Test impact:** None. Tests already mock `articles.extractor.trafilatura`, which still works with function-level imports.

### 3. History Storage — New Module + App Integration

This is the only feature requiring a new file and significant app.py changes.

#### Storage Design: JSON file via platformdirs

**Why JSON over SQLite:** History is a simple list of ~50 entries max. JSON is human-readable, trivially debuggable, no binary dependency. SQLite is overkill.

**Why platformdirs:** Already a Textual dependency (zero new deps). Provides `~/Library/Application Support/articles/` on macOS — the correct XDG-compliant location.

**History file location:** `platformdirs.user_data_dir("articles") / "history.json"`
→ `/Users/<user>/Library/Application Support/articles/history.json`

#### Data Model

```python
# Single history entry
{
    "url": "https://example.com/article",
    "title": "Article Title",
    "read_at": "2025-07-18T10:30:00"   # ISO 8601
}

# history.json — list ordered by recency (newest first)
[
    {"url": "...", "title": "...", "read_at": "..."},
    {"url": "...", "title": "...", "read_at": "..."}
]
```

#### New File: `src/articles/history.py`

```
HistoryStore class:
  __init__(path=None)       — default path from platformdirs
  add(url, title)           — prepend entry, deduplicate by URL, cap at 50
  list() -> list[dict]      — return all entries (newest first)
  _load() -> list[dict]     — read JSON file (empty list if missing)
  _save(entries)            — write JSON file (create dirs if needed)
```

**Design decisions:**
- **Deduplication by URL:** Re-reading the same article updates its timestamp, doesn't create duplicates
- **Cap at 50 entries:** Keeps file small, list scannable, no pagination needed
- **Graceful on missing file:** First launch returns empty list, creates file on first save
- **No async needed:** JSON read/write of 50 entries is <1ms

#### App Integration Points in `app.py`

**1. Welcome screen becomes history-aware:**

```python
# on_mount() changes:
def on_mount(self):
    if self._initial_url:
        self.load_article(self._initial_url)
    else:
        self._show_history_or_welcome()

def _show_history_or_welcome(self):
    history = self._history.list()
    if history:
        # Build markdown list of recent articles as clickable links
        md = "# articles\n\n"
        md += "*Paste a URL to read something new*\n\n---\n\n"
        for entry in history:
            md += f"- [{entry['title']}]({entry['url']})\n"
    else:
        md = WELCOME_MD
    self.query_one("#article", Markdown).update(md)
```

**2. Save to history after successful load:**

```python
# In load_article(), after successful extract + render:
self._history.add(url, title)
```

**3. Re-open from history via link clicks:**

Textual's `Markdown` widget fires `Markdown.LinkClicked` events when links are clicked. This is the clean way to make history entries interactive.

```python
def on_markdown_link_clicked(self, event: Markdown.LinkClicked):
    url = event.href
    if URL_PATTERN.match(url):
        event.prevent_default()
        self.load_article(url)
```

**4. New binding to return to history:**

```python
BINDINGS = [
    ("q", "quit", "Quit"),
    ("h", "history", "History"),  # replaces or supplements "n" (New URL)
]

def action_history(self):
    self._show_history_or_welcome()
```

**5. Constructor gets history store:**

```python
def __init__(self, url=None):
    super().__init__()
    self.theme = "catppuccin-mocha"
    self._initial_url = url
    self._history = HistoryStore()
```

#### Why NOT Separate Screens

The current app uses a single-screen architecture with one `Markdown` widget that swaps content. This works well and is simple:
- Welcome → Article → Welcome cycle via content updates
- No screen stack to manage, no push/pop complexity
- History list rendered as clickable markdown links

Using Textual's `Screen` pattern (push_screen/pop_screen) would add complexity for no benefit — we're just swapping what's displayed in the same layout.

## Recommended Project Structure (v2)

```
src/articles/
├── __init__.py        # unchanged
├── app.py             # MODIFIED — theme, history, link handler
├── cli.py             # unchanged
├── extractor.py       # MODIFIED — lazy trafilatura import
└── history.py         # NEW — HistoryStore class

tests/
├── __init__.py        # unchanged
├── test_app.py        # MODIFIED — theme assertion, history tests
├── test_extractor.py  # unchanged
└── test_history.py    # NEW — HistoryStore unit tests
```

**Deleted:** `src/articles/theme.py`

## Data Flow

### Article Loading (v2)

```
User pastes URL
    ↓
app.py: on_paste() → URL_PATTERN match
    ↓
app.py: load_article(url) — @work thread
    ↓
extractor.py: extract_url(url)
    ↓ (lazy imports trafilatura here)
trafilatura: fetch_url() + extract()
    ↓
app.py: render markdown, extract title
    ↓
history.py: HistoryStore.add(url, title)  ← NEW
    ↓
app.py: update Markdown widget + status bar
```

### History View (new)

```
App launches without URL  (or user presses 'h')
    ↓
app.py: _show_history_or_welcome()
    ↓
history.py: HistoryStore.list() → [entries]
    ↓
app.py: render entries as clickable markdown links
    ↓
User clicks link
    ↓
app.py: on_markdown_link_clicked() → load_article(url)
```

## Build Order (Dependency-Aware)

The three features are nearly independent, but there's one dependency: history display replaces the welcome screen, so theme changes should land first (otherwise tests reference the old theme).

### Recommended order:

**1. Catppuccin Mocha theme (smallest, no deps)**
- Delete `theme.py`
- Update `app.py`: remove import, remove `register_theme()`, set `self.theme = "catppuccin-mocha"`
- Update `test_app.py`: change theme assertion
- Visually verify the new palette looks good

**2. Startup performance (independent, contained)**
- Move `import trafilatura` inside `extract_url()` function body
- Verify tests still pass (mocking works the same)
- Measure: confirm startup drops from ~890ms to ~360ms

**3. History (builds on working app)**
- Create `history.py` with `HistoryStore`
- Create `test_history.py`
- Modify `app.py`: add HistoryStore, update `on_mount`, add `on_markdown_link_clicked`, add history binding
- Update `test_app.py`: add history integration tests

**Rationale:** Theme first because it's a 5-line change with zero risk. Performance second because it's a 2-line change. History last because it's the most complex and benefits from a stable, fast-starting app to develop against.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Over-Engineering History with SQLite

**What people do:** Use SQLite for a simple list of 50 items
**Why it's wrong:** Adds binary file, migration complexity, query overhead — all for data that fits in a 5KB JSON file
**Do this instead:** JSON file with `platformdirs` for the path. Graduate to SQLite only if history grows past thousands of entries (it won't for a personal reader)

### Anti-Pattern 2: Separate Screen for History

**What people do:** Create a `HistoryScreen(Screen)` and use push_screen/pop_screen
**Why it's wrong:** The app has one layout (status + scrollable content + footer). History is just different content in the same layout. Screen switching adds navigation complexity, animation overhead, and state management for zero UX benefit.
**Do this instead:** Render history as markdown in the existing `Markdown` widget. Use clickable links for re-opening.

### Anti-Pattern 3: Eager-Loading Everything at Import Time

**What people do:** `import trafilatura` at module top level because "that's where imports go"
**Why it's wrong:** trafilatura alone adds 530ms to startup. Users see a blank terminal for nearly a second before the TUI appears.
**Do this instead:** Lazy import inside the function that uses it. The function already runs in a background thread with a loading indicator — the import delay is invisible there.

### Anti-Pattern 4: Custom Theme When Built-In Exists

**What people do:** Create a custom Theme object with Catppuccin colors copied from the palette docs
**Why it's wrong:** Textual already ships `catppuccin-mocha` with proper integration, all the right CSS variables, and future-proof updates when Textual upgrades
**Do this instead:** `self.theme = "catppuccin-mocha"` — one line, zero maintenance

## Sources

- **Textual 8.1.1** — verified built-in themes via `App().available_themes` (live inspection, HIGH confidence)
- **Textual Theme API** — verified `Theme.__init__` signature, `register_theme()` not needed for built-ins (live inspection, HIGH confidence)
- **Catppuccin Mocha colors** — verified via live theme object inspection: primary=#F5C2E7, background=#181825, etc. (HIGH confidence)
- **Markdown CSS variables** — verified defaults in `textual/design.py`: headers default to theme primary color (HIGH confidence)
- **Import timing** — measured via `time.perf_counter()` in venv: textual ~360ms, trafilatura ~530ms (HIGH confidence)
- **platformdirs** — confirmed as Textual transitive dependency via `pip show textual | grep Requires` (HIGH confidence)
- **OptionList/Markdown.LinkClicked** — verified widget API via live inspection (HIGH confidence)

---
*Architecture research for: articles v2.0 — history, Catppuccin Mocha, startup performance*
*Researched: 2025-07-18*
