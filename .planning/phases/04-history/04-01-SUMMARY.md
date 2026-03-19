---
phase: 04-history
plan: 01
subsystem: storage
tags: [pathlib, markdown, frontmatter, file-io, persistence]

# Dependency graph
requires:
  - phase: 02-reader
    provides: "extract_url() returns markdown content that gets saved to history"
provides:
  - "save_article() — persist articles as YYMMDD-Title.md with URL frontmatter"
  - "list_history() — directory listing as history index, sorted most-recent-first"
  - "load_article_content() — load markdown without frontmatter"
  - "HISTORY_DIR constant — src/articles/history/ path"
affects: [04-02-PLAN, app-integration, welcome-screen]

# Tech tracking
tech-stack:
  added: []
  patterns: [file-based-persistence, yaml-frontmatter, directory-as-index]

key-files:
  created: [src/articles/history.py, tests/test_history.py]
  modified: []

key-decisions:
  - "load_article_content strips leading newlines after frontmatter for clean content return"

patterns-established:
  - "YAML frontmatter in .md files: ---\\nurl: URL\\n--- as metadata envelope"
  - "YYMMDD-Title.md naming for chronological sort via filename"
  - "tmp_history fixture with monkeypatch.setattr for test isolation of HISTORY_DIR"

requirements-completed: [HIST-03]

# Metrics
duration: 3min
completed: 2026-03-19
---

# Phase 4 Plan 1: History Storage Module Summary

**File-based article persistence with YYMMDD-Title.md naming, URL frontmatter, duplicate overwrite, and 15 unit tests**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-19T09:57:31Z
- **Completed:** 2026-03-19T10:01:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- History storage module with save/list/load functions using pathlib file I/O
- Articles persisted as markdown files with YAML frontmatter (URL metadata)
- Duplicate URL handling: old file deleted, new one created with updated date
- 15 comprehensive unit tests with zero regressions across the full 23-test suite

## Task Commits

Each task was committed atomically:

1. **Task 1: Create history storage module** — TDD RED `cd51642` → GREEN `c5b4fa2` (feat)
2. **Task 2: Create history module tests** — `14a6b88` (test) + cleanup `b9cd46b` (chore)

## Files Created/Modified
- `src/articles/history.py` — History persistence layer: save_article, list_history, load_article_content, plus private helpers _sanitize_title, _title_from_filename, _read_url_from_frontmatter
- `tests/test_history.py` — 15 tests covering save (8), list (3), load (2), and private helpers (2)

## Decisions Made
- `load_article_content` strips leading newlines after frontmatter with `.lstrip("\n")` — ensures clean content return matching original input

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] load_article_content returned leading newline**
- **Found during:** Task 2 (test_load_returns_original_content)
- **Issue:** Content after frontmatter included a leading `\n` because `save_article` writes `\n\n` between `---` and content
- **Fix:** Added `.lstrip("\n")` to the return value in `load_article_content`
- **Files modified:** src/articles/history.py
- **Verification:** test_load_returns_original_content passes — content matches original
- **Committed in:** 14a6b88 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for content integrity. No scope creep.

## Issues Encountered
None

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- History storage API complete and tested — ready for TUI integration in 04-02-PLAN
- `save_article` ready to call from `load_article()` in app.py after successful extraction
- `list_history` ready to populate welcome screen history list
- `load_article_content` ready for re-opening articles from history

---
*Phase: 04-history*
*Completed: 2026-03-19*
