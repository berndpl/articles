# Feature Landscape

**Domain:** Terminal article reader — v2.0 milestone (history, theme, performance)
**Researched:** 2025-07-14
**Overall confidence:** HIGH — all three features verified against live codebase and Textual 8.1.1 APIs

## Table Stakes

Features users expect for a v2.0 reader. Missing = product feels stagnant.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Reading history list on welcome screen | Users re-read articles, need to find "that thing I read yesterday" | Medium | Replaces bare "Paste a URL" welcome with a useful recently-read list |
| Re-open article from history | History without re-open is useless decoration | Low | Selecting a history entry loads the URL through existing `load_article()` |
| Persist history across sessions | History that vanishes on quit is not history | Low | JSON file at `~/Library/Application Support/articles/history.json` via `platformdirs` (already a transitive dep of Textual) |
| Faster startup | ~1.1s current startup is noticeably sluggish for a "paste and read" tool | Low | Lazy-import trafilatura saves ~370ms — the single highest-impact fix |

## Differentiators

Features that elevate the reading experience. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Catppuccin Mocha theme | Community-standard dark palette — looks polished, familiar to terminal enthusiasts | Low | **Built-in to Textual 8.1.1** — literally `self.theme = "catppuccin-mocha"`, no registration needed |
| Custom markdown header colors within Catppuccin | Default Catppuccin uses pink (#F5C2E7) for all H1-H3; custom variables can differentiate heading levels | Low | Override `markdown-h1-color`, `markdown-h2-color` etc. with distinct Catppuccin palette colors (mauve, peach, green) |
| History entry metadata (title + domain + date) | Show article title and source, not just raw URLs — helps users find what they're looking for | Low | Title is already extracted in `load_article()`; domain parsed from URL; timestamp from `time.time()` |
| Clear history action | Users want control over their reading trail | Low | Simple keybinding to clear the JSON file |
| History search/filter | Find a specific past article in a long history | Medium | Textual's `Input` widget + filter on OptionList; defer unless history grows large |

## Anti-Features

Features to explicitly NOT build in v2.0.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| SQLite for history storage | Overkill for ~50-100 recent entries; adds complexity for no gain | JSON file — human-readable, trivially debuggable, no schema migrations |
| Full offline article cache | PROJECT.md explicitly marks this out of scope ("read once, move on") | Store only metadata (URL, title, timestamp) not article content |
| Theme picker / multiple themes | Scope creep — v2.0 goal is to switch FROM cappuccino TO catppuccin-mocha, not build a theme gallery | Set catppuccin-mocha as the one theme; consider a picker in a future version |
| Bookmark / favorites system | Different concept from history; history is automatic, bookmarks are intentional — adds UI complexity | Let history serve as implicit bookmarks; explicit bookmarks are a v3 feature |
| Background prefetch of history articles | Wastes network, adds complexity, contradicts "read once, move on" philosophy | Fetch only when user selects an article from history |
| Import time optimization via compiled extensions | Diminishing returns after lazy imports; cython/mypyc for a TUI app is absurd | Lazy imports get 90% of the win for 10% of the effort |

## Feature Dependencies

```
Startup Performance (lazy imports)
  └── Independent — no dependencies, do first for immediate UX win

Catppuccin Mocha Theme
  └── Independent — swaps theme.py, touches app.py __init__
  └── May want to adjust CSS variables for markdown header differentiation

Article History (persistence layer)
  └── Requires: platformdirs (already installed as Textual transitive dep)
  └── Creates: history.py module with load/save/add functions

History on Welcome Screen (UI integration)
  └── Requires: Article History persistence layer
  └── Requires: Catppuccin Mocha theme (so history list renders in final theme)
  └── Modifies: app.py welcome screen, compose() method
  └── Uses: Textual OptionList widget with OptionSelected message

Re-open from History
  └── Requires: History on Welcome Screen
  └── Wires: OptionList.OptionSelected → load_article(url)
```

## Detailed Feature Analysis

### 1. Startup Performance — Lazy Imports

**Current state (verified via `python -X importtime`):**
- Total import time to `ArticlesApp` ready: **~1,120ms**
- `trafilatura` chain: **~370ms** (charset_normalizer 110ms, htmldate 104ms, trafilatura.settings 196ms)
- `textual` chain: **~560ms** (unavoidable — it's the framework)
- `ArticlesApp()` construction: **~8ms** (negligible)

**Fix:** Move `import trafilatura` from module-level in `extractor.py` to inside `extract_url()`. The app.py import `from articles.extractor import extract_url` then only imports the function signature, not the entire trafilatura tree.

**Expected improvement:** ~370ms saved → startup drops from ~1.1s to ~0.75s.

**Complexity:** Low — one-line change in `extractor.py`. No behavioral change; trafilatura loads on first article fetch (which already shows a "Fetching..." status bar).

### 2. Catppuccin Mocha Theme

**Current state (verified against Textual 8.1.1):**
- Textual ships `catppuccin-mocha` as a built-in theme — confirmed via `App.available_themes`
- No `register_theme()` call needed — just `self.theme = "catppuccin-mocha"`
- Built-in palette: background #181825, foreground #cdd6f4, primary #F5C2E7 (pink), accent #fab387 (peach), surface #313244, panel #45475a

**Markdown header behavior (verified via `textual/design.py`):**
- Textual auto-derives `markdown-h1-color` from `primary` when not explicitly set
- Built-in catppuccin-mocha does NOT set markdown-specific variables
- Result: H1, H2, H3 all render in #F5C2E7 (pink) — same color, different text-style (bold vs underline)
- **Recommendation:** Override markdown header variables to use distinct Catppuccin Mocha palette colors for visual hierarchy:
  - H1: `#cba6f7` (Mauve) — bold, centered (default Textual H1 behavior)
  - H2: `#fab387` (Peach) — underline
  - H3: `#a6e3a1` (Green) — bold

**Migration path:**
1. Remove `CAPPUCCINO` theme definition from `theme.py` (or repurpose file for variable overrides)
2. In `app.py` `__init__`: remove `self.register_theme(CAPPUCCINO)`, set `self.theme = "catppuccin-mocha"`
3. Optionally: register a derived theme that extends catppuccin-mocha with markdown header variable overrides

**Complexity:** Low — primarily deletion of custom theme code, replaced by one-liner.

### 3. Article Reading History

**Storage approach (verified):**
- `platformdirs` is already installed (Textual transitive dependency, v4.9.4)
- Path: `~/Library/Application Support/articles/history.json` on macOS
- Format: JSON array of `{url, title, domain, timestamp}` objects
- Cap at ~50 most recent entries (trim oldest on add)
- No new dependencies required

**Data model:**
```python
@dataclass
class HistoryEntry:
    url: str
    title: str
    domain: str       # extracted from URL for display
    timestamp: float  # time.time()
```

**Persistence pattern:**
- `load_history()` → reads JSON, returns list of HistoryEntry
- `add_to_history(url, title)` → appends entry, trims to max, writes JSON
- File creation: lazy (create on first article read, not on app startup)
- Error handling: if file is corrupt/missing, return empty list (never crash)

**UI integration (verified against Textual OptionList API):**
- Textual `OptionList` widget — purpose-built for selectable lists
- `OptionList.OptionSelected` message fires on selection with `.option` and `.index`
- `Option(prompt, id)` — use `id` to store the URL, `prompt` for display text
- Display format: `"Article Title — example.com"` with relative timestamp
- Replace welcome `Markdown` content with `OptionList` when history exists; show "Paste a URL" as first/header item regardless

**Recording history:**
- Hook into `load_article()` success path — after content renders, call `add_to_history(url, title)`
- Deduplicate: if URL already in history, update timestamp (move to top)

**Complexity:** Medium — new module (`history.py`), new widget integration in `app.py`, file I/O with error handling.

## MVP Recommendation

Prioritize in this order (based on dependency chain and impact):

1. **Startup performance** (lazy trafilatura import) — immediate UX win, zero risk, unblocks nothing but should ship first for clean baseline measurement
2. **Catppuccin Mocha theme switch** — visual refresh, low effort, sets the palette before building history UI on top of it
3. **History persistence layer** (`history.py`) — data model and file I/O, independent of UI
4. **History welcome screen integration** — wire OptionList into app.py, connect to load_article()

**Defer to future:**
- History search/filter — only useful once history list is long; premature now
- Theme picker — v2.0 is about switching to one good theme, not building a theme browser
- Bookmarks — different mental model from automatic history; v3 scope

## Sources

- **Textual 8.1.1 API** — verified directly via Python introspection against installed package (HIGH confidence)
- **Textual built-in themes** — `App.available_themes` confirmed `catppuccin-mocha` present (HIGH confidence)
- **Textual `design.py`** — confirmed markdown header color auto-derivation from `primary` (HIGH confidence)
- **Import profiling** — `python -X importtime` against live codebase (HIGH confidence)
- **platformdirs 4.9.4** — confirmed as existing transitive dependency via `textual` (HIGH confidence)
- **OptionList widget** — `OptionSelected` message, `Option(prompt, id)` constructor verified (HIGH confidence)
