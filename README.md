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

## Safari Share Integration

Read articles directly from Safari without switching to the terminal first.

### Setup (one time)

1. Open **Shortcuts.app**
2. Create a new shortcut named **Read Article**
3. Add a single **Run AppleScript** action with this code:
   ```applescript
   on run {input, parameters}
       set theURL to (item 1 of input) as text
       tell application "Terminal"
           activate
           do script "/Users/berndplontsch/.local/bin/articles '" & theURL & "'"
       end tell
       return input
   end run
   ```
4. In the shortcut details (ⓘ), enable **Show in Share Sheet**
5. Set **Share Sheet Types** to **URLs** only

### Usage

In Safari, tap the **Share** button (or ⌘⇧S) → choose **Read Article**. Terminal.app opens and displays the article.

## Dependencies

- [trafilatura](https://trafilatura.readthedocs.io/) — article extraction (`pipx install trafilatura`)
- [glow](https://github.com/charmbracelet/glow) — terminal markdown renderer
- [gum](https://github.com/charmbracelet/gum) — terminal UI components
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder for browsing
- [crush](https://github.com/charmbracelet/crush) — AI prompt processing
