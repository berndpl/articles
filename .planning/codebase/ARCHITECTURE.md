# Architecture

**Analysis Date:** 2026-03-18

## Pattern Overview

**Overall:** Multi-agent orchestrated workflow system — The GSD (Get Shit Done) framework uses a command/workflow/agent pattern where user commands trigger orchestrated workflows that compose specialized agents. Each agent loads full context once, operates independently, and reports back to the orchestrator.

**Key Characteristics:**
- Decoupled workflow orchestration: Workflows in YAML/Markdown define steps and agent invocations
- Stateful project state: Central STATE.md file tracks project metadata, decisions, progress, and session continuity
- Wave-based parallel execution: Plans are grouped by dependency waves for safe concurrent execution
- Tool-driven CLI operations: `gsd-tools.cjs` provides atomic operations (state reads/writes, phase management, frontmatter CRUD)
- Context-once loading pattern: Each agent loads all needed context in a single init call, reducing back-and-forth
- Markdown-based specifications: ROADMAP.md, REQUIREMENTS.md, CONTEXT.md drive planning and execution
- Subagent delegation: Orchestrator coordinates; subagents execute plans with full independence

## Layers

**Command Layer:**
- Purpose: User-facing entry points (e.g., `/gsd:new-project`, `/gsd:plan-phase`, `/gsd:execute-phase`)
- Location: `.claude/commands/gsd/` (command stubs) and `.claude/get-shit-done/workflows/` (full implementations)
- Contains: Command documentation, argument parsing, user interaction orchestration
- Depends on: Workflows
- Used by: Users via Claude Code `/gsd:` slash commands

**Workflow Layer:**
- Purpose: Define multi-step processes that combine agents, state mutations, and tool invocations
- Location: `.claude/get-shit-done/workflows/` (`.md` files with `<process>` sections)
- Contains: Step-by-step instructions, agent invocation templates, decision logic, file I/O operations
- Depends on: Agents, Tools, State system
- Used by: Commands

**Agent Layer:**
- Purpose: Specialized AI workers (research, planning, code execution, verification)
- Location: `.claude/agents/` (`.md` files defining agent behavior and tools)
- Contains: Role definitions, reasoning patterns, tool access policies, output templates
- Depends on: Tools (Read, Bash, Grep, Write, Glob), STACK.md/CONVENTIONS.md/ARCHITECTURE.md
- Used by: Workflows via agent invocation

**Tools Layer:**
- Purpose: Provide CLI operations for state management, file manipulation, git operations, validation
- Location: `.claude/get-shit-done/bin/gsd-tools.cjs` (CLI router) and `.claude/get-shit-done/bin/lib/*.cjs` (implementations)
- Contains: Modular command handlers (state.cjs, phase.cjs, verify.cjs, frontmatter.cjs, config.cjs, etc.)
- Depends on: File system, Git, Node.js standard library
- Used by: Workflows, agents via bash execution

**Storage Layer:**
- Purpose: Persistent project state and specifications
- Location: `.planning/` (project root directory)
- Contains: CONFIG.json, STATE.md, ROADMAP.md, REQUIREMENTS.md, phases/*/PLAN.md, phases/*/SUMMARY.md
- Depends on: File system, git
- Used by: Tools, workflows

**Hooks Layer:**
- Purpose: Non-intrusive monitoring and system health
- Location: `.claude/hooks/` (JavaScript files)
- Contains: Context monitoring, update checks, statusline display
- Depends on: Session info, file system
- Used by: Claude Code runtime

## Data Flow

**New Project Flow:**

1. User invokes `/gsd:new-project [--auto] [idea document]`
2. Workflow initializes: `init new-project` → loads project context, model assignments, config
3. If brownfield detected: offer codebase mapping (runs `/gsd:map-codebase`)
4. Questioning phase: Project researcher agent gathers domain/requirements via conversation
5. Synthesize: Research synthesizer creates PROJECT.md with context, table stakes, feature list
6. Roadmap generation: Roadmapper creates ROADMAP.md with phase breakdown
7. Requirements extraction: Phase requirements mapped to REQUIREMENTS.md with req IDs
8. State initialization: CONFIG.json, STATE.md created with defaults
9. Output: Project ready, shows next steps (`/gsd:plan-phase 1`)

**Phase Planning Flow:**

1. User invokes `/gsd:plan-phase {N}` with optional `--prd` flag
2. Workflow initializes: `init plan-phase` → loads phase info, research flag, model assignments
3. **Optional Research**: If enabled, phase researcher reads ROADMAP phase goal + references, conducts research, outputs findings to phase research file
4. **Planning**: Planner agent reads CONTEXT.md (phase requirements, implementation decisions, refs), creates PLAN.md with tasks
5. **Plan Checking**: Plan checker agent verifies plan achieves goals, identifies gaps, suggests revisions (max 3 rounds)
6. **Verification**: All plans must pass checks before phase execution allowed
7. Output: PLAN.md written with task breakdown, ready for execution

**Phase Execution Flow:**

1. User invokes `/gsd:execute-phase {N}`
2. Workflow initializes: `init execute-phase` → loads plans, wave grouping, branching config
3. **Wave Discovery**: Plans indexed by dependency wave (e.g., Wave 1: [01-01, 01-02], Wave 2: [01-03])
4. **Wave Execution**: For each wave:
   - If parallelization enabled: All plans in wave spawned as parallel agents
   - If sequential: Plans execute one at a time
   - Each executor agent loads its plan, executes tasks, writes SUMMARY.md
   - Executor commits work to git (if commit_docs enabled)
5. **Verification**: After each plan completes, optional verifier agent checks if implementation matches acceptance criteria
6. **Checkpoints**: Orchestrator pauses between waves (allows user to inspect/pause)
7. Output: All SUMMARY.md files written, git commits created, state updated with completion metrics

**State Mutations:**

All state changes flow through `gsd-tools.cjs state` subcommands:
- `state update <field> <value>` — Single field write
- `state patch --field val ...` — Batch multi-field update
- `state record-metric --phase N --plan M --duration Xmin` — Log execution metrics
- `state add-decision --summary "..." --phase N` — Record architecture decisions
- `state record-session --stopped-at "timestamp"` — Session continuity checkpoint

**State Management:**

- Atomic: Each operation is a complete read-modify-write cycle on STATE.md
- Frontmatter-based: Metadata stored in YAML frontmatter (accessed via `frontmatter get/set/merge`)
- Content-based: Long-form content (decisions, blockers) stored in markdown sections
- Append-only: All decisions, sessions, metrics appended (never deleted, facilitating audit trail)

## Key Abstractions

**Phase:**
- Purpose: Represents a logical milestone/sprint containing multiple plans
- Examples: `.planning/phases/1-backend-setup`, `.planning/phases/2.1-database-schema`
- Pattern: Directory named `{padded_phase}-{slug}` containing PLAN.md, SUMMARY.md, and supporting docs (CONTEXT.md, research.md, etc.)
- Operations: Create, list, complete, renumber, archive (via phase.cjs)

**Plan:**
- Purpose: Atomic unit of work assigned to a single executor agent
- Examples: `.planning/phases/1-backend-setup/01-01-PLAN.md`, `.planning/phases/1-backend-setup/01-02-PLAN.md`
- Pattern: Frontmatter with metadata (objective, wave, files_modified, tasks), task list, acceptance criteria, must_haves
- Wave grouping: Plans with no dependencies execute together (Wave 1), plans depending on Wave 1 form Wave 2, etc.

**Wave:**
- Purpose: Group of plans that can execute in parallel (no interdependencies)
- Examples: Wave 1 = [01-01, 01-02], Wave 2 = [01-03]
- Pattern: Computed from plan dependency graph on each execution
- Safety: Orchestrator blocks wave N until all plans in wave N-1 complete

**CONTEXT.md:**
- Purpose: Captured phase requirements, decisions, and research findings for planner agent
- Pattern: Frontmatter + domain section (phase boundary), decisions section (locked choices), references section (specs/ADRs)
- Creation: Generated by phase researcher or plan-phase workflow
- Consumption: Read by planner agent to understand "what to build" before writing tasks

**Milestone:**
- Purpose: Group multiple phases into shippable releases (v1.0, v1.1, v2.0)
- Examples: `.planning/milestones/v1.0/`, `.planning/milestones/v1.0-phases/`
- Pattern: Directory structure with M.REQUIREMENTS.md (aggregated), SUMMARY.md (aggregated metrics), and archived phases
- Operations: `complete-milestone <version>` archives phases and generates MILESTONES.md entry

**ROADMAP.md:**
- Purpose: Master specification of all phases, requirements, and project scope
- Pattern: Phase sections with goal, user stories, acceptance criteria, canonical references
- Mutation: Phases added/removed via `phase add`, `phase remove`, `phase complete`
- Consumption: Read by phase-researcher to understand phase goals, by verifier to extract acceptance criteria

## Entry Points

**Command Entry (User-Facing):**
- Location: `.claude/commands/gsd/*.md` (command stubs)
- Examples: `execute-phase.md`, `plan-phase.md`, `new-project.md`
- Triggers: User slash command `/gsd:execute-phase 1`
- Responsibilities: Parse command arguments, dispatch to workflow

**Workflow Entry (Orchestration):**
- Location: `.claude/get-shit-done/workflows/*.md`
- Examples: `execute-phase.md` (full workflow), `plan-phase.md`
- Triggers: Command dispatch or parent workflow (e.g., autonomous chains)
- Responsibilities: Multi-step orchestration, agent spawning, state updates, checkpoints

**Agent Entry (Specialized Workers):**
- Location: `.claude/agents/gsd-*.md`
- Examples: `gsd-executor.md`, `gsd-planner.md`, `gsd-project-researcher.md`
- Triggers: Workflow invocation with context
- Responsibilities: Single-purpose task (research, plan, execute, verify), output generation

**Tool Entry (Atomic Operations):**
- Location: `.claude/get-shit-done/bin/gsd-tools.cjs`
- Examples: `state load`, `phase add`, `verify-summary`
- Triggers: Workflow bash invocations like `node gsd-tools.cjs state load`
- Responsibilities: File I/O, git operations, validation, frontmatter manipulation

## Error Handling

**Strategy:** Fail-fast with clear recovery paths. Workflows check preconditions upfront and error early rather than entering workflows.

**Patterns:**

**Validation Errors** (detected before starting work):
```
const result = gsd-tools state load
if [[ ! $result.planning_exists ]]; then
  Error: ".planning/ not found. Run `/gsd:new-project` first"
  Exit 1
fi
```

**State Consistency Errors**:
```
gsd-tools validate consistency
# Checks: phase numbers sequential, disk matches roadmap, all PLAN.md have SUMMARY.md or are incomplete
# If issues: Either auto-repair (e.g., renumber) or error with fix instructions
```

**Phase Not Found Errors**:
```
PHASE_INFO=$(gsd-tools roadmap get-phase 5)
if [[ $PHASE_INFO.found == false ]]; then
  Error: "Phase 5 not found. Available: 1, 2, 2.1, 3"
  Exit 1
fi
```

**Git Conflicts**:
```
git checkout -b branch_name 2>/dev/null || git checkout "$branch_name"
# If already exists on remote and has diverged: Error with merge instructions
```

**Agent Failures**:
```
Plan execution via executor agent fails (SUMMARY.md not created)
→ Workflow catches missing output, reports: "Plan 1.1 execution incomplete"
→ User can retry or manually inspect phase directory
```

## Cross-Cutting Concerns

**Logging:** No centralized logging. Each workflow outputs status to stdout/stderr with banner headers. Agents include timestamps in frontmatter. Metrics recorded in STATE.md.

**Validation:** Three layers:
- Pre-flight (state load checks `.planning/` exists)
- Mid-flight (phase number format, file existence checks)
- Post-flight (verify commands check plan structure, references resolve, artifacts exist)

**Authentication:** None — operates on local file system and git. User is implicitly authenticated if they can run bash.

**Session Continuity:** Tracked via STATE.md `session_history` field. Records when work stopped and when resumed, with `resume_file` path for context on restart. Hooks monitor session info from Claude Code runtime.

---

*Architecture analysis: 2026-03-18*
