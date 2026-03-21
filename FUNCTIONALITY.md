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

## Rewrite Stack

- **Fetch + convert**: `w3m -dump <url>` (plain text extraction, zero deps)
- **Save**: `.md` files in `~/.articles/` (or configurable dir)
- **Read/browse history**: `glow` TUI (built-in file browser + renderer)
- **Glue**: Pure bash script — `fzf` and `gum` available if needed
- **No Python, no pip, no venv** — just shell + tools already on the system
