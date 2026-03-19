# Research Summary: articles v2.0

**Domain:** Terminal article reader — history, theming, performance
**Researched:** 2025-07-18
**Overall confidence:** HIGH

## Executive Summary

The v2.0 milestone (history storage, Catppuccin Mocha theme, startup performance) requires **zero new dependencies**. This is the headline finding. Every feature can be built with what's already installed or part of the Python standard library.

Textual 8.1.1 ships with `catppuccin-mocha` as a built-in theme — the entire theme migration is a one-line change. The custom `CAPPUCCINO` theme in `theme.py` can be deleted. History storage is a 50-entry JSON file using stdlib `json` + `pathlib` + `platformdirs` (already installed as a Textual transitive dependency). Startup performance is dominated by a ~430ms `trafilatura` import that can be deferred to first URL load via lazy import.

The risk profile for this milestone is very low. All three features have clear, well-understood implementations. The only area requiring design judgment is the history UI — specifically how to present the history list in the welcome screen and handle article re-opening.

## Key Findings

**Stack:** Zero new dependencies. Textual built-in theme, stdlib JSON, lazy imports.
**Architecture:** New `history.py` module, modified welcome screen, lazy extractor.
**Critical pitfall:** Don't install `catppuccin` PyPI package — Textual's built-in theme is sufficient and authoritative.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Catppuccin Mocha theme** — Lowest risk, fastest to verify visually
   - Addresses: Theme migration from custom cappuccino to official palette
   - Avoids: Blocked dependencies, complex integration
   - Effort: ~30 minutes (delete theme.py, one-line change, visual check)

2. **Startup performance** — Independent, measurable, fast
   - Addresses: Slow launch time (~937ms → ~500ms)
   - Avoids: Premature optimization (the fix is surgical — one lazy import)
   - Effort: ~15 minutes (move one import statement, verify with timing)

3. **Article history** — Most complex, depends on UI decisions
   - Addresses: History storage, welcome screen redesign, re-open flow
   - Avoids: Building on stale theme (theme done first)
   - Effort: ~2-4 hours (history module, welcome screen widget, integration)

**Phase ordering rationale:**
- Theme first because it changes the visual baseline all other work is tested against
- Startup perf second because it's a one-line fix with measurable results
- History last because it's the most complex and benefits from stable theme/perf

**Research flags for phases:**
- Theme: No further research needed — built-in, verified
- Startup: No further research needed — measured, fix identified
- History: May need light research on Textual `ListView`/`OptionList` for the history list widget

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified all claims against installed packages |
| Features | HIGH | Clear scope from PROJECT.md, straightforward implementations |
| Architecture | HIGH | Small additions to existing well-understood codebase |
| Pitfalls | HIGH | Main risk (unnecessary deps) identified and documented |

## Gaps to Address

- Textual `ListView` vs `OptionList` for history display — decide during implementation
- Whether to show history as markdown in existing widget or as a separate widget mode
- Whether re-opening from history should use cached content or re-fetch (PROJECT.md says no offline caching, so re-fetch)
