# Coding Conventions

**Analysis Date:** 2026-03-18

## Repository Status

**Note:** This repository currently contains only GSD (Get Shit Done) framework infrastructure. No application codebase is present. Conventions documented below are observed in the existing GSD hook infrastructure located in `.claude/hooks/`.

## Naming Patterns

**Files:**
- Kebab-case with functional prefix: `gsd-{function-name}.js`
- Examples: `gsd-check-update.js`, `gsd-statusline.js`, `gsd-context-monitor.js`

**Functions:**
- camelCase for all function declarations
- Descriptive names indicating purpose: `detectConfigDir()`, `clearTimeout()`, `writeFileSync()`
- Prefix with verb when performing actions: `spawn`, `detect`, `check`, `emit`

**Variables:**
- camelCase for all variable declarations
- Descriptive names with clear intent: `homeDir`, `cacheFile`, `metricsPath`, `sessionId`
- ALL_CAPS for constant values: `WARNING_THRESHOLD`, `CRITICAL_THRESHOLD`, `STALE_SECONDS`, `DEBOUNCE_CALLS`
- Prefixed with `is` for boolean flags: `firstWarn`, `isCritical`, `isGsdActive`

**Types:**
- JavaScript (no TypeScript present) - uses implicit typing
- Objects with clear property names: `{ update_available: boolean, installed: string, latest: string, checked: number }`

## Code Style

**Formatting:**
- No formatter detected (Prettier/ESLint not configured)
- Manual formatting conventions observed:
  - 2-space indentation consistently used
  - Single line if statements for simple conditions: `if (remaining != null) { ... }`
  - Multiline objects with proper indentation
  - Spacing after keywords: `const`, `if`, `for`
  - No trailing semicolons on many statements (inconsistent)

**Linting:**
- No linting rules detected
- Manual code quality observed through patterns

## Import Organization

**Order:**
1. Built-in Node.js modules: `const fs = require('fs');`, `const path = require('path');`
2. Standard library: `const os = require('os');`
3. Child process utilities: `const { spawn } = require('child_process');`, `const { execSync } = require('child_process');`

**Pattern:**
- CommonJS `require()` syntax exclusively (no ES6 imports)
- Destructuring used for selective imports: `const { spawn } = require('child_process');`
- All imports at top of file

**Path Handling:**
- `path.join()` for cross-platform path construction
- `path.basename()` for extracting directory names
- Full path composition before use

## Error Handling

**Patterns:**
- Try-catch blocks for risky operations with silent failures by design
- Example from `gsd-check-update.js` line 54-60:
  ```javascript
  try {
    if (fs.existsSync(projectVersionFile)) {
      installed = fs.readFileSync(projectVersionFile, 'utf8').trim();
    } else if (fs.existsSync(globalVersionFile)) {
      installed = fs.readFileSync(globalVersionFile, 'utf8').trim();
    }
  } catch (e) {}
  ```
- Empty catch blocks indicate intentional error suppression
- No error logging - failures degrade gracefully
- Process timeout guards to prevent hanging: `setTimeout(() => process.exit(0), 3000);`

**Strategy:**
- Fail silently and exit gracefully rather than throw
- Validate file existence before operations with `fs.existsSync()`
- Parse protection with try-catch around JSON operations
- Graceful degradation when optional features unavailable

## Logging

**Framework:** `console` not used - No logging framework detected

**Patterns:**
- No logging present in code
- Silent failures by design
- Output only via `process.stdout.write()` for hook return values
- Stderr not used

## Comments

**When to Comment:**
- Explanatory comments for non-obvious logic
- Section markers for major functional blocks
- Inline comments for complex calculations

**Examples:**
- Line 12 in `gsd-statusline.js`: "// Timeout guard: if stdin doesn't close within 3s..."
- Line 26 in `gsd-statusline.js`: "// Context window display (shows USED percentage scaled...)"
- Line 46-47 in `gsd-context-monitor.js`: "// Check if context warnings are disabled..."

**JSDoc/TSDoc:**
- Shebang headers used: `#!/usr/bin/env node`
- File-level comments with purpose:
  ```javascript
  // Check for GSD updates in background, write result to cache
  // Called by SessionStart hook - runs once per session
  ```
- No formal JSDoc blocks observed

## Function Design

**Size:**
- Functions kept small and focused (10-50 lines typical)
- Examples: `detectConfigDir()` is 12 lines, single responsibility

**Parameters:**
- Minimal parameters (1-2 max)
- Use object parameters for multiple related values when needed
- Direct environment variable reading instead of parameter passing

**Return Values:**
- Functions used for side effects often return void
- File I/O operations stored in variables
- Spawn operations unref'd: `child.unref();` to detach background processes

**Early Returns:**
- Used to exit functions when conditions not met
- Example: `if (!sessionId) { process.exit(0); }`

## Module Design

**Exports:**
- No explicit exports in hook files
- Scripts designed as CLI executables (executable permissions via shebang)
- Immediate execution on require - side effects at module level

**Execution Model:**
- All code runs immediately when script is invoked
- Stdin/stdout used for hook communication
- Background spawned processes communicate via file I/O (JSON files)

## Process Management

**Pattern:**
- `spawn()` for background processes: `const child = spawn(process.execPath, [...]);`
- `child.unref()` to allow parent process to exit without waiting
- `windowsHide: true` for Windows process hiding
- `detached: true` on Windows for proper process detachment

**Stdio:**
- `stdio: 'ignore'` for background processes (no output capture)
- `process.stdin` for receiving hook input as JSON
- `process.stdout.write()` for returning structured output

## File System Conventions

**Patterns:**
- Always check existence before reading: `if (fs.existsSync(path)) { ... }`
- `recursive: true` when creating directories: `fs.mkdirSync(cacheDir, { recursive: true });`
- UTF-8 encoding explicitly specified: `.readFileSync(file, 'utf8')`
- JSON.stringify/parse for structured data persistence

**Cache/Temp Files:**
- `.json` extension for structured data
- Temp directory via `os.tmpdir()`
- Session-based file isolation: `claude-ctx-{session_id}.json`

## Environment Variables

**Usage:**
- Read with `process.env.VARIABLE_NAME`
- Environment variable overrides checked first before defaults
- Example: `process.env.CLAUDE_CONFIG_DIR` for config directory override
- Example: `process.env.GEMINI_API_KEY` to detect runtime environment

---

*Convention analysis: 2026-03-18*

**Note:** Conventions are based on GSD infrastructure hooks only. When application code is added to this repository, new conventions should be established for the primary codebase.
