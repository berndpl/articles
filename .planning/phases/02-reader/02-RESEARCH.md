# Phase 2: Reader - Research

**Researched:** 2026-03-19
**Domain:** Textual TUI — markdown article reading, custom theming, paste-to-read, async extraction
**Confidence:** HIGH

## Summary

Phase 2 builds the core reading TUI using Textual 8.1.1 (already installed). The app needs: a Markdown widget inside a scrollable container for article display, a custom cappuccino/mocha theme via Textual's `Theme` + `register_theme` API, paste-to-read via the `Paste` event with URL detection, and async extraction via the `@work(thread=True)` decorator to avoid freezing the UI.

**Critical finding:** The existing `extract_url()` uses `w3m -dump` which produces **plain text** — no markdown structure (no `#` headers, no `**bold**`, no `[links](url)`). DISP-01 requires "headers visually distinct, bold text bold, links visible", which needs actual markdown input for the `Markdown` widget. The extractor must be enhanced to return markdown. Recommended approach: use `trafilatura` (Python library, article-only content extraction with markdown output) or `html2text` (simpler, converts full HTML to markdown). This stays true to the "no headless browser" philosophy while meeting display requirements.

**Primary recommendation:** Use `VerticalScroll` container with `Markdown` widget inside, custom `Theme` for cappuccino palette, `@work(thread=True)` for extraction, `on_paste` for URL detection. Enhance extractor to return markdown via `trafilatura` or `html2text`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Reading layout:** Responsive content width (~80 chars centered on wide terminals, full-width on narrow). Header shows article page title (dynamic). Subtle footer with keybinding hints (q=quit, n=new URL, arrows, page up/down). Links visible but non-interactive.
- **Cappuccino/mocha theme:** Dark mocha base (deep brown background, cream text). Warm accent (burnt orange or cinnamon for headers). Code blocks subtle (slightly different brown). Header/footer chrome matches mocha theme.
- **URL input flow:** Paste-only while reading — no visible input field. Auto-detect URL on paste, load immediately. On failure: show error inline, keep current article. Launch without URL: welcome screen with "Paste a URL to start reading" hint.
- **Loading & transitions:** Step-by-step progress ("Fetching... Extracting... Rendering...") in header/footer. Non-intrusive — current article stays visible. Article swap instant — old disappears, new appears at top.

### Claude's Discretion
- Exact color hex values for the mocha palette
- Footer keybinding hint formatting and layout
- Responsive width breakpoint
- Welcome screen visual design
- Error notification style and duration
- After-read navigation flow (q=quit app vs q=return to welcome)
- How to extract page title from output

### Deferred Ideas (OUT OF SCOPE)
- Article history list on launch screen (v2 — HIST-01, HIST-02)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISP-01 | Rendered markdown formatting (headers, bold, links) | Textual `Markdown` widget renders markdown-it GFM. **Requires markdown input** — extractor must be enhanced from plain text to markdown output. CSS variables `$markdown-h1-color`, `$markdown-h2-color` etc. enable header styling. |
| DISP-02 | Cappuccino/mocha color theme | Textual `Theme` class + `register_theme()`. Custom theme with `background`, `foreground`, `primary`, `accent`, `surface`, `panel` + `variables` dict for markdown/footer/scrollbar colors. |
| NAV-01 | Scroll up/down with arrow keys | `VerticalScroll` container has `can_focus=True` and built-in `up`/`down` → `scroll_up`/`scroll_down` bindings. Put `Markdown` widget inside `VerticalScroll`. |
| NAV-02 | Page up/page down | `VerticalScroll` has built-in `pageup`/`pagedown` → `page_up`/`page_down` bindings. Works out of the box. |
| EXTR-02 | Loading indicator during fetch/extract | Use `Static` widget in header/footer area updated with progress text ("Fetching… Extracting… Rendering…"). Or use widget `.loading` reactive property for built-in spinner. |
| INPT-01 | Paste URL and auto-load article | `textual.events.Paste` event fires `on_paste(event)` with `event.text`. Regex-detect URL in pasted text, trigger extraction worker. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| textual | 8.1.1 | TUI framework — widgets, layout, theming, events | Already installed. Markdown widget, Theme API, Paste event, worker system. |
| trafilatura | 2.0.0 | Article content extraction → markdown | Extracts article-only content (strips nav/sidebar/footer), outputs markdown with headers/bold/links. Python-native, no headless browser. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| html2text | 2025.4.15 | HTML → markdown conversion | Lighter alternative to trafilatura if full-page markdown is acceptable (includes nav/sidebar noise) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| trafilatura | html2text | Lighter (zero deps) but converts full page HTML including navigation — more noise in article view |
| trafilatura | w3m -dump (current) | Plain text only — no markdown headers, bold, or links. Fails DISP-01. |
| VerticalScroll + Markdown | MarkdownViewer | Built-in scrollable markdown viewer BUT `can_focus=False` by default — needs subclass override. Less layout control. |

**Installation:**
```bash
pip install "trafilatura>=2.0.0"
```

Add to `pyproject.toml` dependencies:
```toml
dependencies = [
    "textual>=0.47.0",
    "trafilatura>=2.0.0",
]
```

**Version verification:** textual 8.1.1 confirmed installed. trafilatura 2.0.0 is latest on PyPI (2026).

## Architecture Patterns

### Recommended Project Structure
```
src/articles/
├── __init__.py          # existing
├── extractor.py         # MODIFY: add markdown extraction (trafilatura)
├── cli.py               # MODIFY: launch Textual app instead of print
├── app.py               # NEW: Textual App class, compose, theme, paste handler
└── theme.py             # NEW: cappuccino Theme definition
tests/
├── test_extractor.py    # existing (update for new extraction)
└── test_app.py          # NEW: TUI tests using App.run_test() + Pilot
```

### Pattern 1: Textual App with Custom Theme
**What:** Define a custom `Theme`, register it in the App, use CSS class variable for layout
**When to use:** Any Textual app needing custom colors

```python
from textual.app import App, ComposeResult
from textual.theme import Theme
from textual.containers import VerticalScroll
from textual.widgets import Markdown, Static, Footer

CAPPUCCINO = Theme(
    name="cappuccino",
    primary="#D2691E",       # cinnamon — headers
    secondary="#8B4513",     # saddle brown
    background="#2C1810",    # dark mocha base
    foreground="#F5DEB3",    # cream text
    surface="#3E2723",       # slightly lighter brown
    panel="#4E342E",         # footer/header chrome
    accent="#CD853F",        # burnt orange accent
    warning="#DEB887",
    error="#CD5C5C",
    success="#8FBC8F",
    dark=True,
    variables={
        "markdown-h1-color": "#D2691E",   # cinnamon headers
        "markdown-h1-text-style": "bold",
        "markdown-h2-color": "#CD853F",   # burnt orange
        "markdown-h2-text-style": "bold",
        "footer-background": "#3E2723",
        "scrollbar": "#5D4037",
        "scrollbar-background": "#2C1810",
    },
)

class ArticlesApp(App):
    CSS = """
    VerticalScroll {
        align-horizontal: center;
    }
    Markdown {
        max-width: 88;
        margin: 0 auto;
        padding: 1 2;
    }
    #status {
        dock: bottom;
        height: 1;
        background: $panel;
        color: $foreground;
    }
    """
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("n", "new_url", "New URL"),
    ]

    def __init__(self):
        super().__init__()
        self.register_theme(CAPPUCCINO)
        self.theme = "cappuccino"
```

### Pattern 2: Paste-to-Read with URL Detection
**What:** Detect URLs from paste events, trigger async extraction
**When to use:** INPT-01 paste-to-read flow

```python
import re
from textual.events import Paste

URL_PATTERN = re.compile(r"https?://[^\s<>\"]+")

class ArticlesApp(App):
    def on_paste(self, event: Paste) -> None:
        match = URL_PATTERN.search(event.text)
        if match:
            url = match.group()
            self.load_article(url)
```

### Pattern 3: Threaded Worker for Extraction
**What:** Run blocking extraction in a thread to keep TUI responsive
**When to use:** EXTR-02 loading indicator + non-blocking extraction

```python
from textual import work

class ArticlesApp(App):
    @work(thread=True, exclusive=True, group="extraction")
    def load_article(self, url: str) -> None:
        """Extract article in background thread."""
        # Update status (call_from_thread for UI updates from worker)
        self.call_from_thread(self._set_status, f"Fetching {url}...")
        
        try:
            content = extract_url(url)  # blocking call, OK in thread
            self.call_from_thread(self._set_status, "Rendering...")
            self.call_from_thread(self._display_article, content, url)
        except (ValueError, RuntimeError) as exc:
            self.call_from_thread(self.notify, str(exc), severity="error")
        finally:
            self.call_from_thread(self._set_status, "")
```

### Pattern 4: Responsive Content Width via CSS
**What:** Constrained reading column that adapts to terminal width
**When to use:** DISP-01/DISP-02 responsive layout

```css
/* Textual CSS — applied via App.CSS class variable */
Markdown {
    max-width: 88;       /* ~80 chars + padding */
    margin: 0 auto;      /* center horizontally */
    padding: 1 2;        /* vertical 1, horizontal 2 */
}
```

Note: Textual CSS uses integer units (terminal cells), not px/em. `max-width: 88` constrains to 88 columns. On narrow terminals (<88 cols), it fills available width.

### Anti-Patterns to Avoid
- **Using MarkdownViewer directly:** It sets `can_focus = False`, breaking keyboard scroll. Use `VerticalScroll` + `Markdown` instead, or subclass with `can_focus = True`.
- **Blocking the main thread with extraction:** `extract_url()` is synchronous + network-bound. Always use `@work(thread=True)` — without it, the TUI freezes during fetch.
- **Using `self.query_one().update()` from worker thread:** Textual is not thread-safe. Use `self.call_from_thread()` or `self.app.call_from_thread()` to schedule UI updates from workers.
- **Using `app.dark = True/False`:** The `dark` attribute no longer exists in Textual 8.x. Use `app.theme = "theme_name"` instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown rendering | Custom text parser/formatter | `textual.widgets.Markdown` widget | Handles GFM headers, bold, italic, links, code blocks, lists, tables |
| Scrollable content | Manual scroll offset tracking | `VerticalScroll` container | Built-in arrow/page key bindings, scrollbar, focus management |
| Color theming | Manual color constants + per-widget styling | `Theme` + `register_theme()` | Theme variables cascade to all widgets including Markdown sub-components, Footer, scrollbar |
| Article extraction | Regex HTML parsing | `trafilatura.extract()` | Handles content extraction, boilerplate removal, encoding, redirects |
| Loading indicator | Custom animation/spinner | `Static` widget with text update or `widget.loading = True` | Built-in loading indicator support per widget |
| URL detection | Complex URL validation | `re.compile(r"https?://[^\s<>\"]+")` | Simple regex sufficient for paste detection; full RFC validation unnecessary |

## Common Pitfalls

### Pitfall 1: MarkdownViewer can_focus = False
**What goes wrong:** Keyboard scrolling (arrow keys, page up/down) doesn't work
**Why it happens:** `MarkdownViewer` explicitly overrides `can_focus = False` despite inheriting scrollable bindings from `VerticalScroll`
**How to avoid:** Use `VerticalScroll` container with `Markdown` widget inside. VerticalScroll has `can_focus = True` and all scroll bindings.
**Warning signs:** Arrow keys do nothing, focus goes to Footer instead

### Pitfall 2: Worker Thread UI Updates
**What goes wrong:** Race conditions, crashes, or stale UI
**Why it happens:** Calling `widget.update()` directly from a `@work(thread=True)` method — Textual's event loop is not thread-safe
**How to avoid:** Always use `self.call_from_thread(method, *args)` to schedule UI updates from worker threads
**Warning signs:** Intermittent crashes, widgets not updating, "not in the same thread" errors

### Pitfall 3: w3m -dump Returns Plain Text, Not Markdown
**What goes wrong:** The Markdown widget renders content as a single un-styled paragraph — no headers, no bold, no links
**Why it happens:** `w3m -dump` strips ALL formatting. Output is plain text with no markdown markers.
**How to avoid:** Use `trafilatura` or `html2text` to produce markdown output with proper `#` headers, `**bold**`, `[links](url)`. Modify `extract_url()` accordingly.
**Warning signs:** Article appears as a wall of text with no visual hierarchy

### Pitfall 4: Paste Event Contains Extra Characters
**What goes wrong:** URL detection fails or captures garbage
**Why it happens:** Different terminals include newlines, spaces, or surrounding text in paste events
**How to avoid:** Use `URL_PATTERN.search()` (not `match()`) to find URL anywhere in pasted text. Strip whitespace. Handle multi-line pastes.
**Warning signs:** Valid URLs not detected, or URLs with trailing newlines causing extraction failures

### Pitfall 5: Theme Not Applied on Startup
**What goes wrong:** Default Textual theme shows instead of cappuccino
**Why it happens:** Theme must be registered AND set before compose
**How to avoid:** Call `register_theme()` and set `self.theme` in `__init__` before `compose()` runs
**Warning signs:** Blue/purple default Textual colors instead of warm browns

## Code Examples

### Complete App Skeleton
```python
"""Textual TUI for distraction-free article reading."""

import re

from textual import work
from textual.app import App, ComposeResult
from textual.containers import VerticalScroll
from textual.events import Paste
from textual.theme import Theme
from textual.widgets import Footer, Markdown, Static

from articles.extractor import extract_url

URL_PATTERN = re.compile(r"https?://[^\s<>\"]+")

CAPPUCCINO = Theme(
    name="cappuccino",
    primary="#D2691E",
    secondary="#8B4513",
    background="#2C1810",
    foreground="#F5DEB3",
    surface="#3E2723",
    panel="#4E342E",
    accent="#CD853F",
    warning="#DEB887",
    error="#CD5C5C",
    success="#8FBC8F",
    dark=True,
    variables={
        "markdown-h1-color": "#D2691E",
        "markdown-h1-text-style": "bold",
        "markdown-h2-color": "#CD853F",
        "markdown-h2-text-style": "bold",
        "footer-background": "#3E2723",
    },
)


class ArticlesApp(App):
    CSS = """
    #content {
        align-horizontal: center;
    }
    #article {
        max-width: 88;
        margin: 0 auto;
        padding: 1 2;
    }
    #welcome {
        content-align: center middle;
        width: 100%;
        height: 100%;
        color: $foreground 60%;
    }
    #status-bar {
        dock: top;
        height: 1;
        background: $panel;
        color: $foreground;
        padding: 0 2;
    }
    """
    TITLE = "articles"
    BINDINGS = [
        ("q", "quit", "Quit"),
        ("n", "new_url", "New URL"),
    ]

    def __init__(self, url: str | None = None):
        super().__init__()
        self.register_theme(CAPPUCCINO)
        self.theme = "cappuccino"
        self._initial_url = url

    def compose(self) -> ComposeResult:
        yield Static("", id="status-bar")
        with VerticalScroll(id="content"):
            yield Markdown(id="article")
        yield Footer()

    def on_mount(self) -> None:
        if self._initial_url:
            self.load_article(self._initial_url)
        else:
            self.query_one("#article", Markdown).update(
                "# articles\n\nPaste a URL to start reading"
            )

    def on_paste(self, event: Paste) -> None:
        match = URL_PATTERN.search(event.text)
        if match:
            self.load_article(match.group())

    @work(thread=True, exclusive=True, group="loader")
    def load_article(self, url: str) -> None:
        self.call_from_thread(
            self.query_one("#status-bar", Static).update,
            f"Fetching {url}..."
        )
        try:
            content = extract_url(url)
            self.call_from_thread(
                self.query_one("#status-bar", Static).update,
                "Rendering..."
            )
            self.call_from_thread(
                self.query_one("#article", Markdown).update,
                content
            )
            # Extract title from first heading
            title = "articles"
            for line in content.split("\n"):
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
            self.call_from_thread(setattr, self, "title", title)
        except (ValueError, RuntimeError) as exc:
            self.call_from_thread(
                self.notify, str(exc), severity="error", timeout=5
            )
        finally:
            self.call_from_thread(
                self.query_one("#status-bar", Static).update, ""
            )
```

### CLI Entry Point Modification
```python
"""CLI entry point — launches Textual app."""
import sys
from articles.app import ArticlesApp

def main() -> None:
    url = sys.argv[1] if len(sys.argv) > 1 else None
    app = ArticlesApp(url=url)
    app.run()
```

### Extractor Enhancement (trafilatura approach)
```python
"""Article extraction — fetches and converts to markdown."""
import trafilatura

def extract_url(url: str) -> str:
    if not url:
        raise ValueError("URL must not be empty")
    downloaded = trafilatura.fetch_url(url)
    if downloaded is None:
        raise RuntimeError(f"Failed to fetch: {url}")
    result = trafilatura.extract(
        downloaded,
        output_format="markdown",
        include_links=True,
    )
    if not result:
        raise RuntimeError(f"No article content found at: {url}")
    return result
```

### TUI Test Example
```python
"""Tests for the TUI app."""
import pytest
from unittest.mock import patch
from articles.app import ArticlesApp

@pytest.mark.asyncio
async def test_app_launches_with_welcome():
    async with ArticlesApp().run_test() as pilot:
        md = pilot.app.query_one("#article")
        assert "Paste a URL" in md._markdown

@pytest.mark.asyncio
async def test_paste_triggers_load():
    with patch("articles.app.extract_url", return_value="# Test\n\nContent"):
        app = ArticlesApp()
        async with app.run_test() as pilot:
            # Simulate paste event
            app.post_message(Paste("https://example.com"))
            await pilot.pause(0.5)
            md = pilot.app.query_one("#article")
            assert "Test" in md._markdown
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `app.dark = True` | `app.theme = "name"` | Textual ~1.0 | `dark` attr removed; use Theme API |
| Manual `ColorSystem` | `Theme` + `register_theme()` | Textual ~0.50+ | Simpler theme creation |
| `MarkdownViewer` for everything | `VerticalScroll` + `Markdown` | N/A — design choice | Better focus/scroll control |
| `run_worker()` method | `@work` decorator | Textual ~0.30+ | Cleaner worker syntax |

## Open Questions

1. **Trafilatura vs html2text for extraction**
   - What we know: trafilatura extracts article-only content with markdown (best quality). html2text converts full page HTML to markdown (more noise but zero deps).
   - What's unclear: Whether the added dependencies of trafilatura (lxml, dateparser, etc.) are acceptable to the user
   - Recommendation: Use trafilatura — its article extraction is the core value for "distraction-free reading". The extra deps are pure Python, no system binaries.

2. **Exact cappuccino color palette**
   - What we know: Dark brown background, cream text, cinnamon/burnt-orange accents (user-specified direction)
   - What's unclear: Exact hex values that look good in practice
   - Recommendation: Start with the hex values in the Theme example above, iterate visually. All in Claude's discretion.

3. **Title extraction from article content**
   - What we know: trafilatura extracts article titles as `# Heading` in markdown output
   - What's unclear: Consistency across different sites
   - Recommendation: Parse first `# ` line from markdown as title, fallback to "articles"

## Sources

### Primary (HIGH confidence)
- Textual 8.1.1 source code — inspected via Python `inspect` module: Markdown widget, MarkdownViewer, Theme, Paste event, work decorator, VerticalScroll bindings
- `textual.design` module — confirmed CSS variable names: `markdown-h1-color`, `markdown-h2-color`, `footer-background`, `scrollbar`, etc.
- Textual `Theme.__init__` signature — confirmed: name, primary, secondary, warning, error, success, accent, foreground, background, surface, panel, boost, dark, variables
- `MarkdownViewer.can_focus = False` confirmed in source — critical finding for NAV-01/NAV-02

### Secondary (MEDIUM confidence)
- trafilatura 2.0.0 — tested extraction of Wikipedia article, confirmed markdown output with proper headers/bold/links
- html2text 2025.4.15 — tested, confirmed markdown output but includes full page navigation noise
- w3m -dump — confirmed plain text output (no markdown structure)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Textual 8.1.1 API verified via direct introspection
- Architecture: HIGH — all widget/container patterns verified with actual imports and attribute inspection
- Pitfalls: HIGH — MarkdownViewer.can_focus, thread safety, w3m output format all directly verified
- Extraction enhancement: MEDIUM — trafilatura tested but user decision on w3m replacement needed

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable — Textual API unlikely to break in minor versions)
