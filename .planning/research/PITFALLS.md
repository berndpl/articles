# Domain Pitfalls

**Domain:** Adding history, Catppuccin Mocha theme, and startup performance to an existing Python Textual TUI
**Project:** articles (terminal article reader)
**Researched:** 2025-07-14
**Applies to:** Milestone v2.0 — History & Polish

## Critical Pitfalls

Mistakes that cause rewrites, regressions, or user-visible degradation.

### Pitfall 1: trafilatura Imported at Module Level — 1.2s Startup Penalty

**What goes wrong:** The current `extractor.py` has `import trafilatura` at the top level. Since `app.py` imports `from articles.extractor import extract_url`, the entire trafilatura dependency tree (~774 modules, including lxml, courlan, justext, htmldate) loads during the import chain before the TUI even renders.

**Why it happens:** Standard Python convention is top-level imports. Nobody notices the cost until the app feels sluggish on launch.

**Measured impact (this codebase):**
| Import target | Isolated time | Notes |
|---------------|--------------|-------|
| `trafilatura` | **1.18s** | The bottleneck — lxml + NLP deps |
| `textual.app` | 0.33s | Acceptable for a TUI framework |
| `articles.app` (full chain) | 1.02s* | *Shared modules overlap with trafilatura |

Without trafilatura at import time, startup drops from ~1.8s to ~0.37s.

**Consequences:** Users feel a nearly 2-second delay before seeing anything. For a "paste URL and read" tool, this kills the snappy feel.

**Prevention:** Move `import trafilatura` inside the `extract_url()` function body. trafilatura is only needed when actually fetching an article — never at startup. The first article fetch pays a one-time ~1.2s cost (hidden behind the "Fetching..." loading indicator), and every subsequent fetch reuses the cached module.

```python
# extractor.py — BEFORE (slow startup)
import trafilatura

def extract_url(url: str) -> str:
    downloaded = trafilatura.fetch_url(url)
    ...

# extractor.py — AFTER (fast startup)
def extract_url(url: str) -> str:
    import trafilatura  # lazy: only loads when first article is fetched
    downloaded = trafilatura.fetch_url(url)
    ...
```

**Detection:** Run `time articles` from the terminal. If >0.5s before the TUI appears, import overhead is likely the cause. Confirm with `python -X importtime -c "from articles.app import ArticlesApp" 2>&1 | sort -t: -k2 -n | tail -20`.

**Confidence:** HIGH — measured directly on this codebase.

---

### Pitfall 2: SQLite Default Journal Mode Blocks Concurrent Reads

**What goes wrong:** SQLite's default journal mode is "delete" (rollback journal), which takes an exclusive lock during writes. If the app writes to the history database (e.g., saving a newly read article) while another instance or thread tries to read the history list, the reader gets `sqlite3.OperationalError: database is locked`.

**Why it happens:** Developers assume SQLite "just works" for concurrent access. It does — but only with WAL mode enabled.

**Measured (this codebase):** Confirmed that with default journal mode, a concurrent read fails immediately when a write transaction holds a lock.

**Consequences:** If a user opens two `articles` instances (common with terminal multiplexers like tmux), one instance's history write blocks the other's history read. The blocked operation either errors out or hangs until the `timeout` parameter expires.

**Prevention:** Always enable WAL (Write-Ahead Logging) mode immediately after creating the connection:

```python
conn = sqlite3.connect(db_path, timeout=5)
conn.execute("PRAGMA journal_mode=WAL")
```

WAL allows concurrent reads during writes. It creates a `-wal` and `-shm` file alongside the database — this is normal, don't try to clean them up.

**Detection:** Multiple app instances causing intermittent "database is locked" errors.

**Confidence:** HIGH — verified with SQLite 3.51.3 on this system.

---

### Pitfall 3: History DB Reads Block Startup When Shown on Welcome Screen

**What goes wrong:** The welcome screen needs to show a history list. If history is loaded synchronously in `on_mount()` or `compose()`, the TUI blocks until the DB query completes. For a small DB this is fast, but it adds latency to the critical startup path — especially bad if the DB is on a slow filesystem or has grown large.

**Why it happens:** Developers add `history = db.get_recent()` directly in the mount handler because it's the simplest pattern. Works fine with 5 entries. Becomes noticeable with 500+ and compounds with any other startup work.

**Consequences:** Combined with other startup costs, this pushes perceived launch time higher. The TUI appears frozen during the query.

**Prevention:** Load history asynchronously using Textual's `@work` decorator. Show the welcome screen immediately with a placeholder, then populate the history list when the query completes:

```python
def on_mount(self) -> None:
    self.load_history()  # non-blocking

@work(thread=True)
def load_history(self) -> None:
    entries = self.history_db.get_recent(limit=20)
    self.call_from_thread(self._populate_history, entries)
```

**Detection:** TUI takes noticeably longer to render the welcome screen compared to v1.

**Confidence:** HIGH — pattern derived from existing `@work(thread=True)` usage in this codebase's `load_article()`.

---

### Pitfall 4: No Schema Migration Plan — Future Changes Require Manual Hacks

**What goes wrong:** The history database starts with a simple schema (`url TEXT, title TEXT, timestamp REAL`). Later, a feature needs a new column (e.g., `reading_progress REAL`, `excerpt TEXT`). Without a migration system, the developer must write ad-hoc `ALTER TABLE` statements, handle "column already exists" errors, or tell users to delete their database.

**Why it happens:** Schema migration feels like overengineering for a single-table SQLite database. It's not — it's 10 lines of code that prevent future pain.

**Consequences:** Users who upgrade get crashes (`OperationalError: no such column`) or must manually delete their history. Breaking user data is the fastest way to lose trust.

**Prevention:** Add a `schema_version` table on day 1. Check it on startup and run migrations sequentially:

```python
MIGRATIONS = [
    # v1: initial schema
    "CREATE TABLE IF NOT EXISTS history (url TEXT, title TEXT, timestamp REAL)",
    # v2: add excerpt (future example)
    # "ALTER TABLE history ADD COLUMN excerpt TEXT DEFAULT ''",
]

def migrate(conn):
    conn.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER)")
    row = conn.execute("SELECT version FROM schema_version").fetchone()
    current = row[0] if row else 0
    for i, sql in enumerate(MIGRATIONS[current:], start=current):
        conn.execute(sql)
    conn.execute("DELETE FROM schema_version")
    conn.execute("INSERT INTO schema_version VALUES (?)", (len(MIGRATIONS),))
    conn.commit()
```

**Detection:** Second release that touches the DB schema has no clean upgrade path.

**Confidence:** HIGH — standard pattern; not framework-specific.

## Moderate Pitfalls

### Pitfall 5: Forgetting Catppuccin Mocha Is Built Into Textual

**What goes wrong:** The developer creates a new custom `Theme(name="catppuccin-mocha", ...)` with manually transcribed Catppuccin palette values, when Textual 8.1.1 already ships `catppuccin-mocha` as a built-in theme with correct colors, footer styling, input cursors, and border colors.

**Why it happens:** The project already has a custom theme pattern (`CAPPUCCINO` in `theme.py`). Natural instinct is to follow the same pattern for the new theme.

**Measured:** `"catppuccin-mocha" in App().available_themes` → `True`. The built-in theme includes:
- Primary: `#F5C2E7` (pink), Accent: `#fab387` (peach)
- Background: `#181825` (mantle), Surface: `#313244` (surface0)
- Footer, border, cursor, and button variables pre-configured

**Prevention:** Delete `theme.py` entirely. In `app.py.__init__()`, replace `self.register_theme(CAPPUCCINO)` / `self.theme = "cappuccino"` with just `self.theme = "catppuccin-mocha"`.

**Detection:** A `theme.py` file with catppuccin hex values that duplicates what Textual already provides.

**Confidence:** HIGH — verified on Textual 8.1.1 in this project's venv.

---

### Pitfall 6: Custom markdown-h1-color Lost When Switching Themes

**What goes wrong:** The current `CAPPUCCINO` theme sets custom CSS design variables: `markdown-h1-color: #D2691E` (cinnamon), `markdown-h2-color: #CD853F` (burnt orange), `scrollbar: #5D4037`, `scrollbar-background: #2C1810`. The built-in `catppuccin-mocha` does NOT set any of these. After switching, headings default to the theme's `primary` color (`#F5C2E7` pink) and scrollbars use Textual defaults.

**Why it happens:** Textual's design system falls through: if a theme doesn't set `markdown-h1-color`, it defaults to `primary`. This is by design — and correct. But if the developer expected cinnamon-colored headings to persist, they'll be surprised by pink headings.

**Consequences:** Not a bug — the headings will render correctly in catppuccin-mocha pink. But the developer may spend time debugging "why are my headings the wrong color?" when it's working as intended.

**Prevention:** Accept the built-in defaults. Catppuccin Mocha's primary (`#F5C2E7`) as heading color is the intended community palette. If you truly need different heading colors, override them in a custom theme that inherits from the built-in — but you probably don't.

**Detection:** Visually compare headings before and after theme switch.

**Confidence:** HIGH — verified via `textual/design.py` line 326: `colors["markdown-h1-color"] = get("markdown-h1-color", primary.hex)`.

---

### Pitfall 7: Thread-Unsafe History Writes from Worker Threads

**What goes wrong:** The app uses `@work(thread=True)` for `load_article()`. The natural place to record history is after a successful fetch — inside that worker thread. If the history module creates a connection in the main thread and the worker tries to use it, Python's sqlite3 module raises `ProgrammingError: SQLite objects created in a thread can only be used in that same thread` (when `check_same_thread=True`, the default).

**Why it happens:** Developers create a single DB connection at app startup and pass it around. SQLite connections are thread-bound by default.

**Prevention:** Create connections per-operation (open, write, close) or use `check_same_thread=False` with WAL mode. For this app's low-frequency writes (one per article read), connection-per-operation is simpler and safer:

```python
def save_entry(url: str, title: str) -> None:
    conn = sqlite3.connect(DB_PATH, timeout=5)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("INSERT INTO history VALUES (?, ?, ?)", (url, title, time.time()))
    conn.commit()
    conn.close()
```

**Detection:** `ProgrammingError` crash when saving history from the article loader worker thread.

**Confidence:** HIGH — sqlite3 `threadsafety=3` on this system (serialized), but Python's wrapper still enforces `check_same_thread` by default.

---

### Pitfall 8: Missing Parent Directory for Database File

**What goes wrong:** `sqlite3.connect("~/.local/share/articles/history.db")` fails with `OperationalError: unable to open database file` if the `articles/` directory doesn't exist. Tilde (`~`) isn't expanded either.

**Why it happens:** Developers test with an existing directory and forget the first-run case.

**Prevention:** Always expand the path and create parent directories:

```python
from pathlib import Path
db_path = Path.home() / "Library" / "Application Support" / "articles" / "history.db"
db_path.parent.mkdir(parents=True, exist_ok=True)
conn = sqlite3.connect(str(db_path))
```

Use `platformdirs.user_data_dir("articles")` (already installed as a transitive dependency) for cross-platform correctness, though macOS is the primary target.

**Detection:** App crashes on first launch after install.

**Confidence:** HIGH — platformdirs 4.9.4 confirmed available in venv.

---

### Pitfall 9: Profiling the Wrong Thing — Runtime vs Import Time

**What goes wrong:** Developer profiles `app.run()` to diagnose slow startup and finds nothing — the event loop, rendering, and widget creation are all fast. The actual bottleneck is the import chain *before* `app.run()` is even called, which standard profilers (cProfile on `app.run()`) don't capture.

**Why it happens:** "Slow startup" is ambiguously scoped. `cProfile` only measures the profiled function, not module-level import side effects.

**Prevention:** Profile imports separately from runtime:

```bash
# Import profiling (the actual bottleneck)
python -X importtime -c "from articles.app import ArticlesApp" 2>&1 | sort -t: -k2 -n | tail -20

# Runtime profiling (only if import isn't the issue)
python -m cProfile -s cumtime -c "from articles.app import ArticlesApp; ArticlesApp().run()"
```

**Detection:** "I profiled the app and everything's fast" while startup still feels slow.

**Confidence:** HIGH — import-time profiling confirmed trafilatura as bottleneck on this codebase.

## Minor Pitfalls

### Pitfall 10: Storing Full Article Content in History

**What goes wrong:** Temptation to cache the full extracted markdown in the history database so re-opening is instant. This bloats the DB (articles can be 50-100KB of markdown) and creates stale content issues — if the article is updated, the user sees the old version.

**Prevention:** Store only metadata: URL, title, timestamp, optional excerpt (first 200 chars). Re-fetch on re-open. The loading indicator already exists and users expect a brief fetch.

**Confidence:** HIGH — design decision, not technical.

---

### Pitfall 11: Dead Code After Theme Switch

**What goes wrong:** After switching to the built-in `catppuccin-mocha` theme, the entire `theme.py` module and its import in `app.py` become dead code. If not removed, future developers waste time maintaining it or get confused about which theme is active.

**Prevention:** Delete `theme.py` and remove `from articles.theme import CAPPUCCINO` in the same commit as the theme switch.

**Confidence:** HIGH.

---

### Pitfall 12: Unbounded History Table Growth

**What goes wrong:** Without a cap, the history table grows indefinitely. Unlikely to be a real problem for an article reader (users read maybe 5-20 articles/day), but a 10,000-row table with no index on timestamp will slow sorted queries.

**Prevention:** Cap history at a reasonable limit (e.g., 500 entries). Add an index on `timestamp DESC`. Prune old entries on write:

```python
conn.execute("DELETE FROM history WHERE rowid NOT IN (SELECT rowid FROM history ORDER BY timestamp DESC LIMIT 500)")
```

**Confidence:** MEDIUM — unlikely to be a problem in practice for this app's usage pattern, but trivial to prevent.

---

### Pitfall 13: Catppuccin Mocha's Cool Palette vs. Previous Warm Theme

**What goes wrong:** The current cappuccino theme is warm (brown `#2C1810` background, cream `#F5DEB3` text). Catppuccin Mocha is cool (dark blue-purple `#181825` background, light blue `#cdd6f4` text). The reading experience shifts noticeably. Users may feel the app "lost its personality."

**Prevention:** This is a deliberate design choice, not a bug. But test the reading experience with actual long-form articles before shipping. The warm-to-cool shift is more noticeable on long reads. If the warm feel is essential, consider keeping a custom warm theme and offering catppuccin-mocha as an alternative — but this adds theme-switching UI complexity that's probably not worth it for v2.

**Confidence:** HIGH — measured color values from both themes.

---

### Pitfall 14: TYPE_CHECKING Guard Needed for Lazy Imports

**What goes wrong:** After moving `import trafilatura` inside `extract_url()`, type checkers (mypy, pyright) and IDEs lose type information for trafilatura's functions. Autocompletion and type checking degrade.

**Prevention:** Use a `TYPE_CHECKING` guard for type hints while keeping the runtime import lazy:

```python
from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import trafilatura

def extract_url(url: str) -> str:
    import trafilatura
    ...
```

This is only relevant if the project uses type checking. Given the current minimal codebase, it's a minor concern — but good hygiene.

**Confidence:** HIGH — standard Python pattern.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation | Severity |
|-------------|---------------|------------|----------|
| History storage (schema) | No migration plan (Pitfall 4) | Add schema_version table from day 1 | Critical |
| History storage (I/O) | DB reads block startup (Pitfall 3) | Use `@work(thread=True)` for history loading | Critical |
| History storage (threading) | Thread-unsafe DB access (Pitfall 7) | Connection-per-operation pattern | Moderate |
| History storage (filesystem) | Missing parent directory (Pitfall 8) | `mkdir(parents=True, exist_ok=True)` before connect | Moderate |
| History storage (concurrency) | Default journal mode locks (Pitfall 2) | Enable WAL mode on every connection | Critical |
| Catppuccin theme switch | Recreating built-in theme (Pitfall 5) | Just set `self.theme = "catppuccin-mocha"` | Moderate |
| Catppuccin theme switch | Custom CSS variables gone (Pitfall 6) | Accept built-in defaults; they're correct | Moderate |
| Catppuccin theme switch | Dead code left behind (Pitfall 11) | Delete `theme.py` in same commit | Minor |
| Performance optimization | trafilatura at import level (Pitfall 1) | Move import inside function body | Critical |
| Performance optimization | Profiling wrong layer (Pitfall 9) | Use `python -X importtime` first | Moderate |
| Performance optimization | Over-storing in history (Pitfall 10) | Metadata only, re-fetch on open | Minor |

## Recommended Ordering Based on Pitfalls

1. **Performance first** — Fix the lazy import (Pitfall 1) before adding any features. Adding history to the welcome screen without fixing startup performance will make the perceived regression worse. The fix is also the simplest (move one import statement).

2. **Theme switch second** — It's a 3-line change (delete import, change theme name, delete `theme.py`). Do it before history so the history list UI is built against the final theme, not the old one.

3. **History last** — Has the most pitfalls (5 of 14) and the most complexity. Requires careful attention to threading, schema versioning, and async loading. Benefits from having the performance fix and theme already in place.

## Sources

- **Textual 8.1.1 source code** — `textual/theme.py`, `textual/design.py`, `textual/widgets/_markdown.py` (verified in project venv)
- **SQLite WAL documentation** — https://www.sqlite.org/wal.html
- **Python sqlite3 thread safety** — `sqlite3.threadsafety = 3` (measured on this system, Python 3.14)
- **Direct measurement** — All timing data from `time.perf_counter()` runs on this project's codebase
- **platformdirs 4.9.4** — Confirmed available as transitive dependency in project venv
