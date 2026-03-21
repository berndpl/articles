# Articles — Functional Requirements

What the app does, independent of implementation.

## Core Flow

1. **Read an article** — Given a URL, fetch the web page, extract the article content, and display it as readable markdown in the terminal.
2. **Save automatically** — Every fetched article is saved as a local `.md` file with the source URL preserved.
3. **Browse history** — A file browser / list view shows all saved articles, sorted most-recent first. Selecting one opens it for reading.

## Behaviors

- **Duplicate handling** — Fetching the same URL again replaces the old file (updated date).
- **Article files** — Each saved article is a standalone `.md` file (readable outside the app). Source URL stored in YAML frontmatter.
- **Filename convention** — `YYMMDD-slugified-title.md`
- **Navigation** — Switch between history list and article reader. Quit with `q`.
- **CLI usage** — `articles` opens history; `articles <url>` fetches and displays directly.

## Tech Stack

- **Fetch + extract**: `trafilatura` CLI (installed via pipx) — article-only extraction as markdown
- **Read/render**: `glow` — terminal markdown renderer with built-in TUI file browser
- **UI prompts**: `gum` — input prompt for URL paste, spinner while fetching
- **Save**: `.md` files in `history/` subfolder (relative to script)
- **Glue**: Pure bash script (~60 lines)
- **Dependencies**: `trafilatura`, `glow`, `gum` (all via Homebrew / pipx)
