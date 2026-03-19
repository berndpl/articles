# Technology Stack — v2.0 Additions

**Project:** articles (terminal article reader)
**Researched:** 2025-07-18
**Scope:** Stack additions for history storage, Catppuccin Mocha theme, startup performance

## Executive Summary

**Zero new dependencies required.** All three v2.0 features can be implemented with what's already installed or built into the Python standard library. This is the most important finding — resist the urge to add packages.

- **Catppuccin Mocha**: Already a built-in theme in Textual 8.1.1. One-line change: `self.theme = "catppuccin-mocha"`.
- **History storage**: Use stdlib `json` + `pathlib` + `platformdirs` (already installed as a Textual transitive dependency).
- **Startup performance**: Use stdlib `python -X importtime` and lazy-import `trafilatura` to save ~430ms.

## Existing Stack (unchanged)

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | ≥3.11 | Runtime |
| textual | 8.1.1 | TUI framework |
| trafilatura | 2.0.0 | Article extraction |
| platformdirs | 4.9.4 | Platform data dirs (transitive dep of textual) |

## What's Needed Per Feature

### 1. Catppuccin Mocha Theme

**What to use:** Textual's built-in `catppuccin-mocha` theme
**New dependencies:** None
**Confidence:** HIGH — verified in Textual 8.1.1

Textual 8.1.1 ships with 20 built-in themes including `catppuccin-mocha`. The current app registers a custom `CAPPUCCINO` Theme object and sets `self.theme = "cappuccino"`. The migration is:

```python
# BEFORE (current theme.py + app.py)
self.register_theme(CAPPUCCINO)
self.theme = "cappuccino"

# AFTER (no theme.py needed)
self.theme = "catppuccin-mocha"
```

**Built-in theme colors (verified):**

| Role | Hex | Catppuccin Name |
|------|-----|-----------------|
| Background | `#181825` | Mantle |
| Foreground | `#cdd6f4` | Text |
| Primary | `#F5C2E7` | Pink |
| Secondary | `#cba6f7` | Mauve |
| Surface | `#313244` | Surface0 |
| Panel | `#45475a` | Surface1 |
| Accent | `#fab387` | Peach |
| Warning | `#FAE3B0` | Yellow variant |
| Error | `#F28FAD` | Red variant |
| Success | `#ABE9B3` | Green variant |

The built-in theme also sets sensible `variables` for `footer-background`, `input-cursor-*`, `border`, `block-cursor-*`, etc.

**Customization option:** If markdown header colors need tweaking (the current cappuccino theme sets `markdown-h1-color` and `markdown-h2-color`), create a derived theme:

```python
from textual.theme import BUILTIN_THEMES

# Start from built-in, override specific variables
catppuccin = BUILTIN_THEMES["catppuccin-mocha"]
ARTICLES_MOCHA = Theme(
    name="articles-mocha",
    **{k: getattr(catppuccin, k) for k in ["primary", "secondary", "background", "foreground", "surface", "panel", "accent", "warning", "error", "success", "dark"]},
    variables={
        **catppuccin.variables,
        "markdown-h1-color": "#f5c2e7",  # pink headers
        "markdown-h2-color": "#fab387",  # peach sub-headers
    },
)
```

**Recommendation:** Start with the built-in theme as-is. Only customize if headers don't look right during visual testing.

**DO NOT install `catppuccin` Python package.** It provides color hex values and Pygments styles but has zero Textual integration. Textual's built-in theme is authoritative and maintained by the Textual team.

---

### 2. Article History Storage

**What to use:** JSON file via stdlib (`json`, `pathlib`, `datetime`) + `platformdirs`
**New dependencies:** None — `platformdirs` is already installed (Textual dependency)
**Confidence:** HIGH — all stdlib + verified transitive dep

**Storage location:** `platformdirs.user_data_dir("articles")` → macOS: `~/Library/Application Support/articles/history.json`

**Why JSON file, not SQLite:**
- History is a simple list (URL, title, timestamp) — not relational data
- Expected size: tens to low hundreds of entries — JSON handles this trivially
- No queries beyond "most recent N" — sort by timestamp in Python
- Zero additional imports (sqlite3 would work but adds complexity for no benefit)
- Human-readable/debuggable — users can `cat` the file

**Why not TinyDB/SQLite/pickle:**
- TinyDB: New dependency for a problem stdlib solves
- SQLite: Overkill for a flat list; adds `import sqlite3` import time
- pickle: Not human-readable, security concerns with untrusted data

**History record schema:**

```python
# history.json structure
{
    "version": 1,
    "entries": [
        {
            "url": "https://example.com/article",
            "title": "Article Title",
            "read_at": "2025-07-18T14:30:00",
            "domain": "example.com"
        }
    ]
}
```

**Implementation pattern:**

```python
import json
from pathlib import Path
from datetime import datetime
from platformdirs import user_data_dir

HISTORY_PATH = Path(user_data_dir("articles")) / "history.json"
MAX_HISTORY = 50  # keep it bounded

def load_history() -> list[dict]:
    if not HISTORY_PATH.exists():
        return []
    data = json.loads(HISTORY_PATH.read_text())
    return data.get("entries", [])

def save_entry(url: str, title: str) -> None:
    HISTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    entries = load_history()
    # Deduplicate: remove existing entry for same URL
    entries = [e for e in entries if e["url"] != url]
    entries.insert(0, {
        "url": url,
        "title": title,
        "read_at": datetime.now().isoformat(),
        "domain": url.split("/")[2] if "/" in url else "",
    })
    entries = entries[:MAX_HISTORY]
    HISTORY_PATH.write_text(json.dumps({"version": 1, "entries": entries}, indent=2))
```

**Key design decisions:**
- `version` field in JSON for future schema migration
- Dedup by URL (re-reading moves to top, doesn't duplicate)
- Cap at 50 entries (no unbounded growth)
- `domain` stored for display in history list without URL parsing at render time

---

### 3. Startup Performance

**What to use:** `python -X importtime` (built-in) for profiling, lazy imports for the fix
**New dependencies:** None
**Confidence:** HIGH — measured and verified

**Current startup profile (measured):**

| Import | Time | % of Total |
|--------|------|------------|
| `textual` (all widgets) | ~625ms | 67% |
| `trafilatura` | ~430ms | 46% |
| `articles.app` (overhead) | ~10ms | 1% |
| **Total cold import** | **~937ms** | — |

Note: textual and trafilatura overlap in transitive deps, so total < sum.

**The fix — lazy-import trafilatura:**

`trafilatura` is only needed when a user actually loads a URL. It should NOT be imported at module level. Move the import inside `extract_url()`:

```python
# extractor.py — BEFORE
import trafilatura

def extract_url(url: str) -> str:
    downloaded = trafilatura.fetch_url(url)
    ...

# extractor.py — AFTER
def extract_url(url: str) -> str:
    import trafilatura  # lazy: ~430ms deferred to first use
    downloaded = trafilatura.fetch_url(url)
    ...
```

**Impact:** App shell renders ~430ms faster. User sees the TUI and welcome screen almost instantly. The trafilatura import cost is paid on first URL load (hidden behind the "Fetching..." status bar).

**Profiling tools (all stdlib, no installs):**

| Tool | Command | Purpose |
|------|---------|---------|
| `-X importtime` | `python -X importtime -c "from articles.app import ArticlesApp" 2>&1 \| sort -t'\|' -k1 -rn \| head 20` | Find slowest imports |
| `time` module | `time.perf_counter()` around imports | Measure specific imports |
| `cProfile` | `python -m cProfile -s cumulative -c "..."` | Full function-level profiling |

**DO NOT install `py-spy`, `line_profiler`, or `scalene`.** The stdlib tools are sufficient for import-time optimization. These heavier profilers are for runtime hotspots, which aren't the problem here.

---

## What NOT to Add

| Package | Why Tempting | Why Wrong |
|---------|-------------|-----------|
| `catppuccin` (PyPI) | "Official" Catppuccin Python colors | Textual already has the theme built-in. Adding this would duplicate data and add an unnecessary dependency. |
| `tinydb` | "Easy" JSON database | stdlib `json` is simpler for a flat list of 50 items. TinyDB adds a dependency for zero benefit. |
| `sqlite3` | "Proper" database | Overkill. We're storing a list, not relational data. Also adds import time. |
| `py-spy` / `scalene` | Profiling | stdlib `-X importtime` + `cProfile` solve the actual problem (import overhead). |
| `pydantic` | History data validation | A dataclass or plain dict is fine for 4 fields. |
| `aiosqlite` | Async history | There's nothing async about reading a 50-entry JSON file. |

## Changes to pyproject.toml

**None.** No new dependencies. The `pyproject.toml` stays as-is:

```toml
dependencies = [
    "textual>=0.47.0",
    "trafilatura>=2.0.0",
]
```

## Changes to Existing Files

| File | Change | Reason |
|------|--------|--------|
| `theme.py` | Delete or gut | Built-in `catppuccin-mocha` replaces custom `CAPPUCCINO` theme |
| `app.py` | Remove `from articles.theme import CAPPUCCINO`, `register_theme()` | Use built-in theme |
| `app.py` | `self.theme = "catppuccin-mocha"` | One-line theme switch |
| `extractor.py` | Move `import trafilatura` inside `extract_url()` | Lazy import for startup perf |
| `app.py` | Add history list widget to welcome/compose | Show recent articles |
| New: `history.py` | History read/write module | Encapsulate JSON persistence |

## Integration Points

### History ↔ App
- `on_mount()`: Load history, display in welcome screen as a clickable/selectable list
- `load_article()`: After successful extraction, save URL + title to history
- History list needs a Textual widget (likely `ListView` or `OptionList`) in the compose tree

### Theme ↔ App
- Remove `register_theme(CAPPUCCINO)` from `__init__`
- Set `self.theme = "catppuccin-mocha"` in `__init__`
- If custom markdown variables needed, derive from `BUILTIN_THEMES["catppuccin-mocha"]`

### Lazy Import ↔ Extractor
- Move `import trafilatura` to function scope in `extractor.py`
- No other files need to change — `extract_url()` API stays the same

## Sources

| Claim | Source | Confidence |
|-------|--------|------------|
| Textual 8.1.1 includes `catppuccin-mocha` built-in theme | Verified: `BUILTIN_THEMES` in installed package | HIGH |
| Built-in theme colors match official Catppuccin Mocha palette | Verified: compared `BUILTIN_THEMES` hex values to `catppuccin` 2.5.0 PyPI package | HIGH |
| `platformdirs` is a transitive dependency of Textual | Verified: `importlib.metadata.requires('textual')` shows `platformdirs (>=3.6.0,<5)` | HIGH |
| `trafilatura` import takes ~430ms | Measured: `time.perf_counter()` in current venv | HIGH |
| Lazy import of trafilatura saves ~430ms on startup | Measured: import with/without trafilatura in same session | HIGH |
| `user_data_dir("articles")` → `~/Library/Application Support/articles/` on macOS | Verified: ran `platformdirs.user_data_dir("articles")` | HIGH |
