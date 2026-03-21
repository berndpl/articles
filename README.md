# articles

A terminal-based article reader and organizer. Fetch web articles, read them as markdown in the terminal, and process them with AI prompts.

## Usage

```bash
articles              # browse saved articles
articles <url>        # fetch and read an article
```

### Controls

- **Enter** — read selected article
- **→** — process article with an AI prompt (via [crush](https://github.com/charmbracelet/crush))
- **Esc** — quit

## How it works

1. Paste a URL — the article is fetched, cleaned, and saved as a `.md` file in `history/`
2. Browse your reading history with fuzzy search and live preview
3. Process any article with preset AI prompts (summarize, critique, ELI5, etc.)

Articles are saved with YAML frontmatter containing the source URL. Filenames follow `YYMMDD-slugified-title.md`. Fetching the same URL again replaces the old file.

## Dependencies

- [trafilatura](https://trafilatura.readthedocs.io/) — article extraction (`pipx install trafilatura`)
- [glow](https://github.com/charmbracelet/glow) — terminal markdown renderer
- [gum](https://github.com/charmbracelet/gum) — terminal UI components
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder for browsing
- [crush](https://github.com/charmbracelet/crush) — AI prompt processing
