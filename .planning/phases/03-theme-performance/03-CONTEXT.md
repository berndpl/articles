# Phase 3: Theme & Performance - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Switch from custom cappuccino theme to official Catppuccin Mocha palette, remove custom theme code, ensure scrollbar is hidden, and optimize startup to under 500ms. No new features — visual polish and performance only.

</domain>

<decisions>
## Implementation Decisions

### Aesthetic shift
- Accept the full Catppuccin Mocha palette as-is — cool dark base with pastel accents replaces warm browns/cream
- No custom color overrides — use Textual's built-in Catppuccin Mocha theme directly
- This is a deliberate shift from "cozy evening coffee" to the widely-used Catppuccin community palette
- Out of Scope confirms: "Accept default Catppuccin Mocha rendering as-is" — no custom header colors

### Startup optimization
- Primary target: lazy-import trafilatura (top-level import in `extractor.py` is the likely bottleneck)
- Profile first to confirm trafilatura is the culprit, then fix
- If other bottlenecks surface during profiling, fix them too — the goal is <500ms, not just one lazy import

### Scrollbar & visual cleanup
- Scrollbar is already hidden via CSS (`scrollbar-size: 0 0` in `app.py`) — verify it stays hidden after theme switch
- Delete `theme.py` entirely — no custom theme code should remain
- Update `app.py` to use Textual's built-in Catppuccin Mocha instead of registering custom theme
- Remove the `CAPPUCCINO` import and `register_theme`/`self.theme` references

### Claude's Discretion
- Exact Textual API for activating Catppuccin Mocha (built-in theme name, registration method)
- Whether lazy import uses `importlib` or inline import inside function
- Profiling tool choice (time, cProfile, or manual timing)
- Any CSS variable adjustments needed after theme switch (e.g., if `$panel` renders differently)

</decisions>

<canonical_refs>
## Canonical References

No external specs — requirements are fully captured in decisions above and the following planning artifacts:

### Requirements
- `.planning/REQUIREMENTS.md` — THEME-01, THEME-02, THEME-03, PERF-01 define Phase 3 scope

### Prior phase context
- `.planning/phases/02-reader/02-CONTEXT.md` — Cappuccino theme decisions, reading layout, code context

### Codebase
- `src/articles/theme.py` — Custom CAPPUCCINO Theme object to be deleted
- `src/articles/app.py` — Theme registration, CSS with scrollbar hiding, main app class

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app.py` CSS block: scrollbar hiding (`scrollbar-size: 0 0`) already works — keep this CSS
- `app.py` ArticlesApp class: well-structured Textual app, theme is isolated to `__init__` method

### Established Patterns
- Theme registration: `self.register_theme(CAPPUCCINO)` then `self.theme = "cappuccino"` in `__init__`
- All imports are top-level — trafilatura imported in `extractor.py` at module load time
- CSS defined as class variable `CSS = """..."""` in ArticlesApp

### Integration Points
- `theme.py` → `app.py`: only consumer of CAPPUCCINO theme — clean deletion path
- `extractor.py`: trafilatura import at line 3 — needs lazy loading for startup performance
- `cli.py` → `app.py`: entry point chain; cli imports app which imports extractor which imports trafilatura

</code_context>

<specifics>
## Specific Ideas

No specific requirements — accept Catppuccin Mocha defaults and focus on clean implementation.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-theme-performance*
*Context gathered: 2026-03-19*
