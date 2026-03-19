# Phase 4: History - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Add article reading history: save each read article as a markdown file, display history on the welcome screen, and let the user re-open previous articles with keyboard navigation. No bookmarking, no offline caching, no search — just a file-based history list.

</domain>

<decisions>
## Implementation Decisions

### Welcome screen layout
- History list IS the welcome screen — replaces the current static `WELCOME_MD` text
- Paste hint ("Paste a URL to start reading") moves to the footer/status bar area
- All history entries shown in a scrollable list (no cap on visible items)
- First launch with no history: blank screen with paste hint in footer only — no big splash

### History entry display
- Title only — ultra-minimal, no URL or timestamps shown in the list
- Entries ordered by most recent first (filename date prefix provides natural ordering)

### History selection UX
- Arrow keys to highlight + Enter to open — standard list navigation
- Pasting a URL while browsing history still works — loads article immediately
- Replace 'n' (New URL) binding with 'h' / left arrow — one "back" action that returns to the history list from the reader
- 'q' still quits the app

### Storage — markdown files, not JSON
- Each article saved as a `.md` file in a `history/` subdirectory of the app's source package (`src/articles/history/`)
- Filename format: `YYMMDD-[website-title].md` (e.g., `260319-How CSS Grid Works.md`)
- Title truncated to 50 characters if longer
- File content: the extracted markdown article content (same as what's rendered in the reader)
- No separate JSON index — the directory listing IS the history
- No limit on accumulated files — user manages manually

### Duplicate/re-read handling
- Reading the same URL again: overwrite the existing file with updated timestamp in filename
- This naturally bumps re-reads to the top of the chronological list (most recent first)

### Claude's Discretion
- Exact Textual widget for the history list (ListView, DataTable, or custom)
- How to sanitize filenames (strip special chars from titles)
- How to detect duplicate URLs (store URL in file metadata/frontmatter, or match by title)
- Exact "back to history" implementation (key binding registration, action method)
- How to handle articles with no extractable title (fallback naming)
- Whether to use a Textual Screen for history vs modifying the single-screen layout

</decisions>

<canonical_refs>
## Canonical References

No external specs — requirements are fully captured in decisions above and the following planning artifacts:

### Requirements
- `.planning/REQUIREMENTS.md` — HIST-01, HIST-02, HIST-03 define Phase 4 scope

### Prior phase context
- `.planning/phases/02-reader/02-CONTEXT.md` — Welcome screen design, URL input flow, navigation patterns
- `.planning/phases/03-theme-performance/03-CONTEXT.md` — Catppuccin Mocha theme (current visual baseline)

### Codebase
- `src/articles/app.py` — ArticlesApp class, WELCOME_MD, compose(), load_article(), action_new_url()
- `src/articles/extractor.py` — extract_url() returns markdown content (what gets saved to history files)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `extract_url()` in `extractor.py` — returns markdown content; save this directly to history `.md` file after extraction
- `load_article()` in `app.py` — already extracts title from `# heading`; reuse for filename generation
- `WELCOME_MD` constant — will be replaced by dynamic history list widget
- `action_new_url()` — will be replaced by `action_back_to_history()` or similar

### Established Patterns
- Textual `@work(thread=True)` for background I/O — use same pattern for saving history files
- `call_from_thread()` for UI updates from worker threads
- `on_paste()` handles URL detection — keep this working on history screen too
- CSS class variable for layout — extend with history list styling

### Integration Points
- `load_article()` is where history save should happen (after successful extraction, before rendering)
- `compose()` needs a new widget for the history list
- `__init__()` needs to scan `history/` directory on startup to build list
- Key bindings: replace `("n", "new_url", "New URL")` with `("h", "back", "History")` and add left-arrow
- `action_new_url()` → rename/replace with history navigation action

</code_context>

<specifics>
## Specific Ideas

- Filename format explicitly: `YYMMDD-[title].md` — e.g., `260319-How CSS Grid Works.md`
- The history directory IS the source of truth — no database, no index file
- "Back" metaphor: left arrow or 'h' to return to history (like going back in a browser)
- First launch = blank + footer hint — ultra-minimal, no splash screen

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-history*
*Context gathered: 2026-03-19*
