# Codebase Structure

**Analysis Date:** 2026-03-18

## Directory Layout

```
.claude/
├── agents/                              # Specialized AI worker agents
│   ├── gsd-codebase-mapper.md          # Maps codebase and writes STACK/ARCHITECTURE docs
│   ├── gsd-debugger.md                 # Troubleshoots failed executions
│   ├── gsd-executor.md                 # Executes individual plans, writes code
│   ├── gsd-integration-checker.md      # Validates external service integrations
│   ├── gsd-nyquist-auditor.md          # Audits for information theoretical gaps
│   ├── gsd-phase-researcher.md         # Research domain, specs, APIs before planning
│   ├── gsd-plan-checker.md             # Validates plans achieve phase goals
│   ├── gsd-planner.md                  # Creates PLAN.md from CONTEXT.md
│   ├── gsd-project-researcher.md       # Initial questioning and domain research
│   ├── gsd-research-synthesizer.md     # Synthesizes PROJECT.md from research
│   ├── gsd-roadmapper.md               # Creates ROADMAP.md from requirements
│   ├── gsd-ui-auditor.md               # UI/UX review and compliance checking
│   ├── gsd-ui-checker.md               # Verifies UI implementation matches specs
│   ├── gsd-ui-researcher.md            # UI research and design system analysis
│   ├── gsd-verifier.md                 # Post-phase verification against requirements
│   └── gsd-plan-runner.md              # Low-level execution agent (rarely used directly)
│
├── commands/gsd/                        # Command stubs (dispatch to workflows)
│   ├── execute-phase.md                # Invoke: /gsd:execute-phase {phase}
│   ├── plan-phase.md                   # Invoke: /gsd:plan-phase {phase}
│   ├── new-project.md                  # Invoke: /gsd:new-project [--auto]
│   ├── map-codebase.md                 # Invoke: /gsd:map-codebase tech|arch|quality|concerns
│   ├── debug.md                        # Invoke: /gsd:debug [phase]
│   ├── progress.md                     # Invoke: /gsd:progress
│   └── [30+ other commands]            # Quick tasks, phase ops, settings, etc.
│
├── get-shit-done/                      # Framework core (versioned separately)
│   ├── bin/
│   │   ├── gsd-tools.cjs              # Main CLI router (state, phase, verify, template ops)
│   │   └── lib/
│   │       ├── core.cjs               # Shared utilities (path, git, config, output)
│   │       ├── state.cjs              # STATE.md read/write, metrics, decisions
│   │       ├── phase.cjs              # Phase CRUD, decimal logic, archiving
│   │       ├── frontmatter.cjs        # YAML frontmatter extraction/merge
│   │       ├── verify.cjs             # Validation suite (structure, references, commits)
│   │       ├── commands.cjs           # High-level operations (commit, model resolution)
│   │       ├── config.cjs             # CONFIG.json read/write, defaults
│   │       ├── roadmap.cjs            # ROADMAP.md parsing and updates
│   │       ├── template.cjs           # PLAN.md/SUMMARY.md template rendering
│   │       ├── milestone.cjs          # Milestone archiving and completion
│   │       ├── init.cjs               # Multi-agent workflow initialization
│   │       └── model-profiles.cjs     # Model assignments by profile (balanced/fast/thorough)
│   │
│   ├── workflows/                      # Full workflow implementations (orchestration)
│   │   ├── plan-phase.md              # Research → Plan → Check → Done
│   │   ├── execute-phase.md           # Wave discovery → Wave execution → Verify → Done
│   │   ├── execute-plan.md            # Single-plan execution with context injection
│   │   ├── new-project.md             # Questions → Research → Requirements → Roadmap
│   │   ├── new-milestone.md           # Roadmap aggregation → Milestone creation
│   │   ├── complete-milestone.md      # Archive phases, generate MILESTONES.md
│   │   ├── autonomous.md              # Auto-chain phases with optional inter-phase verification
│   │   └── [30+ other workflows]      # Research, UI, debugging, health checks, etc.
│   │
│   ├── references/                     # Standard documents (UI brand, code style guides)
│   │   ├── ui-brand.md                # Design system, colors, typography, components
│   │   ├── code-style-*.md            # Language-specific conventions
│   │   └── [domain-specific refs]     # Architecture patterns, security guides, etc.
│   │
│   ├── templates/                      # Markdown templates (filled via template.cjs)
│   │   ├── PLAN.md                    # Task list template with frontmatter
│   │   ├── SUMMARY.md                 # Execution summary template
│   │   ├── CONTEXT.md                 # Phase context template
│   │   ├── REQUIREMENTS.md            # Requirements list template
│   │   ├── ROADMAP.md                 # Roadmap structure template
│   │   ├── STATE.md                   # Project state template
│   │   ├── PROJECT.md                 # Project overview template
│   │   └── [UAT.md, VERIFICATION.md]  # Testing and verification templates
│   │
│   └── VERSION                         # Current GSD framework version (e.g., "0.9.8")
│
├── hooks/                              # Non-intrusive system observers
│   ├── gsd-statusline.js              # Shows model, context%, current task in Claude Code status
│   ├── gsd-check-update.js            # Detects GSD updates available (runs on session start)
│   └── gsd-context-monitor.js         # Warns when context window low (runs post-tool)
│
├── settings.json                       # Claude Code hooks configuration
├── package.json                        # Minimal npm config (CommonJS)
└── gsd-file-manifest.json             # Manifest of all GSD framework files (for updates)

.planning/                              # Project-specific planning directory (project root)
├── codebase/                          # Codebase analysis docs (written by /gsd:map-codebase)
│   ├── ARCHITECTURE.md                # System design, layers, data flow
│   ├── STRUCTURE.md                   # Directory layout, file locations
│   ├── STACK.md                       # Technology stack (languages, frameworks, deps)
│   ├── INTEGRATIONS.md                # External APIs, services, auth
│   ├── CONVENTIONS.md                 # Code style, naming, patterns
│   └── TESTING.md                     # Test patterns, frameworks, coverage
│
├── CONFIG.json                        # Project configuration (model profile, git strategy, workflow flags)
├── STATE.md                           # Project state (frontmatter: metadata, content: decisions/blockers/sessions)
├── ROADMAP.md                         # Phase breakdown (frontmatter per phase: goal, user stories, acceptance criteria)
├── REQUIREMENTS.md                    # Aggregated requirements with req IDs (e.g., REQ-01, REQ-02)
├── PROJECT.md                         # Project overview (elevator pitch, table stakes, feature breakdown)
│
├── phases/                            # Phase directories (one per phase)
│   ├── 1-backend-setup/               # Phase 1: "Backend Setup"
│   │   ├── CONTEXT.md                 # Phase requirements and locked decisions
│   │   ├── research.md                # Phase research findings (populated by phase researcher)
│   │   ├── 01-01-PLAN.md              # First plan: API setup
│   │   ├── 01-01-SUMMARY.md           # Execution summary for plan 01-01
│   │   ├── 01-02-PLAN.md              # Second plan: Database schema
│   │   ├── 01-02-SUMMARY.md           # Execution summary for plan 01-02
│   │   └── 01-03-PLAN.md              # Third plan: Auth layer (if exists)
│   │
│   ├── 2-frontend-build/              # Phase 2: "Frontend Build"
│   │   ├── CONTEXT.md
│   │   ├── 02-01-PLAN.md
│   │   ├── 02-01-SUMMARY.md
│   │   └── ...
│   │
│   ├── 2.1-ui-polish/                 # Decimal phase: "UI Polish" (sub-phase of 2)
│   │   ├── CONTEXT.md
│   │   ├── 02-01-PLAN.md              # Numbering continues from parent
│   │   └── ...
│   │
│   └── 3-testing-deployment/
│       └── ...
│
├── milestones/                        # Archived milestones (created by /gsd:complete-milestone)
│   ├── v1.0/                          # Milestone v1.0
│   │   ├── M.REQUIREMENTS.md          # Aggregated requirements for this milestone
│   │   ├── SUMMARY.md                 # Milestone completion summary
│   │   └── v1.0-phases/               # Archived phase directories (if --archive-phases)
│   │       ├── 1-backend-setup/
│   │       ├── 2-frontend-build/
│   │       └── ...
│   │
│   └── MILESTONES.md                  # Running record of completed milestones
│
└── todos/                             # Pending work (created by /gsd:add-todo)
    ├── pending/                       # Not yet started
    │   └── *.md                       # Individual todo files
    └── completed/                     # Finished work
        └── *.md
```

## Directory Purposes

**.claude/**
- Home for all Claude Code configuration and extensions
- Isolated from user project code (keep project root clean)
- `.claude/get-shit-done/` versioned separately (update mechanism in hooks)

**.claude/agents/**
- Each agent is a single `.md` file with role, tools, patterns, output templates
- Agents are stateless and idempotent (can be retried safely)
- Always read full context once on startup (via `init` pattern)

**.claude/commands/gsd/**
- Thin dispatch layer (usually 1-5 KB each)
- Route to workflow, parse arguments, call orchestrator
- User-facing: error messages here are seen directly

**.claude/get-shit-done/bin/lib/**
- Modular handlers for each responsibility
- Each module has 1-2 main exports (e.g., `cmdStateLoad`, `cmdStateUpdate`)
- Shared utilities in `core.cjs` (path normalization, git, config loading)

**.planning/**
- Project-specific state and specifications
- Never version-controlled in `.gitignore` (except ROADMAP.md and REQUIREMENTS.md which users may track)
- All write operations atomic: read-modify-write on STATE.md, append to phase directories

**.planning/phases/**
- One directory per phase, named `{padded_number}-{slug}`
- Padded: "01", "02", "2.1" → "02-01"
- Slug: phase name converted to kebab-case (e.g., "Backend Setup" → "backend-setup")
- All plans for a phase in single directory (easy to find, easy to archive)

**.planning/milestones/**
- Read-only archive of completed phases
- Created only when `/gsd:complete-milestone` invoked
- Enables version-based rollback and retrospectives

## Key File Locations

**Entry Points:**
- `.claude/commands/gsd/execute-phase.md` — User runs `/gsd:execute-phase 1`
- `.claude/get-shit-done/workflows/execute-phase.md` — Workflow implementation
- `.planning/phases/1-backend-setup/01-01-PLAN.md` — Executor agent reads this
- `.planning/phases/1-backend-setup/01-01-SUMMARY.md` — Executor writes this

**Configuration:**
- `.claude/settings.json` — Hook definitions for Claude Code
- `.planning/CONFIG.json` — Project-level settings (model profile, branching strategy)
- `.claude/get-shit-done/bin/lib/model-profiles.cjs` — Model assignments by profile

**Core Logic:**
- `.claude/get-shit-done/bin/gsd-tools.cjs` — All state, phase, verify, template operations route here
- `.claude/get-shit-done/bin/lib/state.cjs` — STATE.md mutations
- `.claude/get-shit-done/bin/lib/phase.cjs` — Phase CRUD, renumbering
- `.claude/get-shit-done/bin/lib/verify.cjs` — Plan validation, reference checking

**Testing & Verification:**
- `.planning/phases/{phase}/CONTEXT.md` — Read by gsd-planner, gsd-plan-checker
- `.planning/phases/{phase}/*/PLAN.md` — Spec for what executor must build
- `.planning/phases/{phase}/*/SUMMARY.md` — What executor actually built
- `.planning/REQUIREMENTS.md` — Read by gsd-verifier to check if phase satisfied requirements

## Naming Conventions

**Files:**
- `*.md` — All specifications and documentation (ROADMAP.md, CONTEXT.md, PLAN.md)
- `gsd-*.md` — Agent files (always start with `gsd-` prefix)
- `{N}-{slug}-PLAN.md` — Plan file (e.g., `01-01-PLAN.md`, `2.1-02-PLAN.md`)
- `{N}-{slug}-SUMMARY.md` — Execution summary (paired with PLAN.md)
- `*.cjs` — CommonJS modules (gsd-tools.cjs, lib/*.cjs)
- `*.js` — JavaScript hook scripts

**Directories:**
- `.planning/` — Project planning root (hidden, not user directory)
- `.claude/` — Claude Code extensions (hidden, not user directory)
- `phases/` — All phases grouped (always lowercase)
- `milestones/` — Archived releases (v1.0, v2.0, etc.)
- `{padded_phase}-{slug}/` — Phase directory (e.g., `01-backend-setup`, `2.1-ui-polish`)

**Frontmatter Fields** (in PLAN.md, SUMMARY.md, STATE.md):
- `objective` — What this task delivers
- `wave` — Execution wave (for parallelization)
- `files_modified` — Rough estimate of affected files
- `tasks` — Count of subtasks
- `status` — completed | incomplete | blocked
- `requirements` — Linked REQ-IDs this plan satisfies

**Git Commits** (from gsd-tools commit):
- Prefix: `[gsd] <verb> <subject>` (e.g., `[gsd] plan Phase 1: Backend Setup`)
- Content: Planning docs only (not generated code)
- Co-author: `Co-Authored-By: Claude Opus <noreply@anthropic.com>`

## Where to Add New Code

**New Workflow:**
- Create `.claude/get-shit-done/workflows/my-workflow.md`
- Template: `<purpose>`, `<required_reading>`, `<process>` sections
- Pattern: Initialize with `gsd-tools init ...`, parse JSON, coordinate agents and tool calls
- Register: Add stub in `.claude/commands/gsd/my-command.md` that dispatches to workflow

**New Agent:**
- Create `.claude/agents/gsd-my-worker.md`
- Template: `<role>`, `<instructions>`, `<tools>`, `<patterns>` sections
- Load context: Always use `<files_to_read>` block at top, load once from orchestrator
- Output: Write results to stdout or `.planning/` files (never modify source code files unless directed)

**New State Field:**
- Edit `.planning/STATE.md` frontmatter schema or content sections
- Use `gsd-tools state update --field value` to set
- Read via `gsd-tools state json` or `state get section`

**New Phase Requirement:**
- Add requirement to `.planning/REQUIREMENTS.md` with `REQ-NNN` ID
- Link from phase ROADMAP.md section using `@REQ-NNN`
- Verifier reads requirements to validate completion

**New Template:**
- Create `.claude/get-shit-done/templates/MYTEMPLATE.md`
- Use handlebars syntax: `{{phase}}, {{plan}}, {{objective}}`
- Register in `template.cjs` `cmdTemplateFill` function
- Invoke: `gsd-tools template fill mytemplate --phase 1`

## Special Directories

**`.planning/codebase/`:**
- Purpose: Codebase analysis docs (STACK.md, ARCHITECTURE.md, CONVENTIONS.md, etc.)
- Generated: By `/gsd:map-codebase {focus}` agent
- Committed: Optional (user chooses in `/gsd:new-project`)
- Consumed by: gsd-planner, gsd-executor (to follow coding standards)

**`.planning/phases/`:**
- Purpose: All phase directories live here
- Generated: By `gsd-tools phase add` or create phase dir
- Committed: Yes (all PLAN.md, SUMMARY.md, CONTEXT.md tracked)
- Accessed: By workflows for plan discovery, phase verification

**`.planning/milestones/`:**
- Purpose: Archive of completed milestone phases
- Generated: By `/gsd:complete-milestone` command
- Committed: Yes (separate from active .planning/phases/)
- Read-only: Never modified after creation

**`.claude/hooks/`:**
- Purpose: Non-blocking observers (statusline, update check, context warning)
- Execution: Automatic by Claude Code runtime hooks
- Blocking: No — hooks fail silently if they error
- Customizable: Edit settings.json to enable/disable

---

*Structure analysis: 2026-03-18*
