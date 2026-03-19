# Phase 2: Reader - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Full TUI reading experience using Textual. User can read any web article distraction-free with styled markdown rendering, cappuccino/mocha theme, keyboard navigation (scroll + page), paste-to-read URL input, and a loading indicator. Single-article view — history and multi-article are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Reading layout
- Responsive content width — constrained reading column (~80 chars centered) on wide terminals, full-width on narrow ones
- Header shows the article's page title (dynamic per article, extracted from content)
- Subtle footer with keybinding hints (q=quit, n=new URL, arrows, page up/down)
- Links are visible but non-interactive — styled distinctly (e.g., underlined or different color) but not clickable

### Cappuccino/mocha theme
- Dark mocha base — deep brown background with cream-colored body text
- Warm accent color — burnt orange or cinnamon for headers
- Code blocks are subtle — slightly lighter/darker brown than background, blend in rather than stand out
- Header and footer chrome match the mocha theme — slightly different brown shade, blend into the reading experience rather than contrasting

### URL input flow
- Paste-only while reading — no visible input field; user pastes a URL anywhere and it auto-detects and loads
- On paste: brief "Loading [url]..." indicator appears, then the new article replaces the current one
- No confirmation dialog — paste triggers load immediately with visual feedback
- On extraction failure: show error as inline notification, keep the current article on screen (don't lose what they're reading)
- Launch without URL: welcome screen with app name and "Paste a URL to start reading" hint

### Loading & transitions
- Step-by-step progress feel — "Fetching... Extracting... Rendering..." shown in header or footer area
- Loading indicator is non-intrusive — appears in header/footer only, current article stays fully visible while loading
- Article swap is instant — old article disappears, new article appears at the top immediately
- After-read navigation: Claude's discretion on whether 'q' quits vs returns to welcome screen

### Claude's Discretion
- Exact color hex values for the mocha palette (dark brown, cream, burnt orange/cinnamon)
- Footer keybinding hint formatting and layout
- Responsive width breakpoint (when to switch from constrained to full-width)
- Welcome screen visual design (centered text, any ASCII art, etc.)
- Error notification style and duration
- After-read navigation flow (q=quit app vs q=return to welcome)
- How to extract page title from w3m output (first line heuristic, etc.)

</decisions>

<specifics>
## Specific Ideas

- User wants a history list on launch (select from previously read articles) — deferred to v2 but signals the launch screen should be designed with future history integration in mind
- Dark mocha feel is intentional: "like dark mode coffee" — cozy evening reading vibes
- The reader should feel immersive — minimal chrome, content-first
- Step-by-step loading progress ("Fetching... Extracting... Rendering...") gives the user confidence the app is working, not frozen

</specifics>

<canonical_refs>
## Canonical References

No external specs — requirements are fully captured in decisions above and the following planning artifacts:

### Requirements
- `.planning/REQUIREMENTS.md` — DISP-01, DISP-02, NAV-01, NAV-02, EXTR-02, INPT-01 define Phase 2 scope

### Phase 1 outputs
- `.planning/phases/01-foundation/01-01-SUMMARY.md` — extract_url() API, CLI entry point, test patterns established

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/articles/extractor.py` → `extract_url(url: str) -> str`: Blocking w3m subprocess call. Returns plain text. Raises ValueError (empty URL) or RuntimeError (w3m failures). Must be called from a Textual worker thread to avoid freezing the TUI.
- `src/articles/cli.py` → `main()`: Current CLI entry point registered as `articles = "articles.cli:main"`. Needs modification to launch Textual app instead of printing to stdout. Keep optional URL argument support.
- `tests/test_extractor.py`: 5 unit tests using `unittest.mock.patch()` on subprocess — pattern to follow for TUI tests.

### Established Patterns
- Package structure: `src/articles/` layout with `pyproject.toml` at root
- Subprocess wrapper: validate input → run subprocess → check returncode → return stdout
- Error handling: ValueError for input validation, RuntimeError for external tool failures

### Integration Points
- `cli.py` is the entry point — needs to launch the Textual App, optionally passing a URL from sys.argv
- `extract_url()` is the data source — called from TUI worker threads on paste or launch-with-URL
- `pyproject.toml` already has `textual>=0.47.0` as dependency — no new deps needed for core TUI
- Textual's built-in `Markdown` widget handles rendering; `Paste` message handles URL detection

</code_context>

<deferred>
## Deferred Ideas

- **Article history list on launch screen** — User wants to see previously read articles and select one to reopen. Maps to v2 requirements HIST-01 and HIST-02. Design the welcome screen with future history integration in mind.

</deferred>

---

*Phase: 02-reader*
*Context gathered: 2026-03-19*
