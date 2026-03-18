---
phase: 01-foundation
plan: "01"
subsystem: cli
tags: [python, w3m, subprocess, pytest, setuptools, textual]

# Dependency graph
requires: []
provides:
  - "articles Python package with setuptools build config"
  - "extract_url() function using w3m -dump subprocess"
  - "articles CLI command (articles.cli:main) installable via pip install -e ."
  - "5 unit tests for extractor with full subprocess mocking"
affects: [02-tui, future-phases]

# Tech tracking
tech-stack:
  added: [python3.14, setuptools, pytest, w3m, textual>=0.47.0]
  patterns: [subprocess-wrapper-with-error-handling, tdd-red-green, editable-package-install]

key-files:
  created:
    - pyproject.toml
    - src/articles/__init__.py
    - src/articles/extractor.py
    - src/articles/cli.py
    - tests/__init__.py
    - tests/test_extractor.py
  modified: []

key-decisions:
  - "Used setuptools.build_meta backend instead of setuptools.backends.legacy — setuptools 82 does not have the legacy backend module"
  - "w3m invoked via subprocess.run with capture_output=True, timeout=30 — clean, no parsing needed"
  - "CLI uses sys.argv directly — no argparse needed for single positional argument"

patterns-established:
  - "Subprocess wrapper pattern: validate input, run subprocess, check returncode, return stdout"
  - "TDD cycle: commit RED (failing tests), then GREEN (implementation + passing tests)"
  - "Package structure: src/articles/ layout with pyproject.toml at root"

requirements-completed: [EXTR-01, INPT-02]

# Metrics
duration: 4min
completed: 2026-03-18
---

# Phase 1 Plan 01: Foundation Summary

**w3m-based extract_url() function and articles CLI command, installable Python package with 5 passing unit tests**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-18T14:21:47Z
- **Completed:** 2026-03-18T14:25:26Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Python package scaffold with pyproject.toml, src/articles/ layout, and CLI entry point registration
- w3m-based extract_url() function: wraps subprocess, handles empty URL, missing w3m, timeout, nonzero exit
- articles CLI command: accepts optional URL, prints content or usage, exits correctly on errors
- 5 unit tests using subprocess mocking — no network calls required

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing extractor tests** - `8b6f2fb` (test)
2. **Task 1 GREEN: w3m extractor implementation** - `cd68fc0` (feat)
3. **Task 2: CLI entry point** - `d242e37` (feat)

_Note: TDD task 1 has two commits (test RED → feat GREEN)_

## Files Created/Modified

- `pyproject.toml` - Package definition, CLI entry point `articles = "articles.cli:main"`, build config
- `src/articles/__init__.py` - Package marker (empty)
- `src/articles/extractor.py` - extract_url() using w3m subprocess
- `src/articles/cli.py` - main() CLI entry point, wired to extract_url()
- `tests/__init__.py` - Test package marker (empty)
- `tests/test_extractor.py` - 5 unit tests with MagicMock subprocess patching

## Decisions Made

- Used `setuptools.build_meta` backend instead of `setuptools.backends.legacy` — the legacy backend module does not exist in setuptools 82 (auto-fixed blocking issue)
- w3m invoked with `subprocess.run(["w3m", "-dump", url], capture_output=True, text=True, timeout=30)` — simple, no parsing
- CLI uses `sys.argv` directly — argparse unnecessary for a single positional argument

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed build backend incompatibility with setuptools 82**
- **Found during:** Task 1 (package install via pip install -e .)
- **Issue:** Plan specified `setuptools.backends.legacy:build` as build backend, but setuptools 82 does not expose this module — `BackendUnavailable` error on pip install
- **Fix:** Changed build-backend to `setuptools.build_meta` (standard setuptools backend, works on all versions)
- **Files modified:** pyproject.toml
- **Verification:** `pip install -e .` succeeded, package imports correctly
- **Committed in:** cd68fc0 (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for any installation to work. No scope creep — same functionality, correct backend identifier.

## Issues Encountered

None beyond the build backend deviation above.

## User Setup Required

None - no external service configuration required. Runtime dependency w3m is available at `/opt/homebrew/bin/w3m`.

## Next Phase Readiness

- extract_url() and articles CLI are complete and tested — ready for Phase 2 TUI integration
- Package installs cleanly via `pip install -e .` in a venv
- w3m confirmed working: `articles https://example.com` returns plain text from the live site
- Blocker from STATE.md resolved: w3m is installed at `/opt/homebrew/bin/w3m`

## Self-Check: PASSED

- pyproject.toml: FOUND
- src/articles/__init__.py: FOUND
- src/articles/extractor.py: FOUND
- src/articles/cli.py: FOUND
- tests/__init__.py: FOUND
- tests/test_extractor.py: FOUND
- .planning/phases/01-foundation/01-01-SUMMARY.md: FOUND
- Commit 8b6f2fb: FOUND
- Commit cd68fc0: FOUND
- Commit d242e37: FOUND

---
*Phase: 01-foundation*
*Completed: 2026-03-18*
