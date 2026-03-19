"""History persistence — save, list, and load articles as markdown files."""

import re
from datetime import datetime
from pathlib import Path

HISTORY_DIR = Path(__file__).parent / "history"


def save_article(url: str, title: str, content: str) -> Path:
    """Save an article as a markdown file with URL frontmatter.

    If the URL already exists in history, the old file is deleted
    and a new one is created with an updated date prefix.

    Returns:
        Path to the created file.
    """
    HISTORY_DIR.mkdir(exist_ok=True)

    # Remove existing file for same URL (duplicate handling)
    for path in HISTORY_DIR.glob("*.md"):
        if _read_url_from_frontmatter(path) == url:
            path.unlink()
            break

    date_prefix = datetime.now().strftime("%y%m%d")
    safe_title = _sanitize_title(title)[:50]
    if not safe_title:
        safe_title = "untitled"

    filename = f"{date_prefix}-{safe_title}.md"
    filepath = HISTORY_DIR / filename
    filepath.write_text(f"---\nurl: {url}\n---\n\n{content}")
    return filepath


def list_history() -> list[dict]:
    """Return history entries sorted by filename descending (most recent first).

    Each entry is a dict with keys: title, url, path.
    Returns an empty list if the history directory doesn't exist.
    """
    if not HISTORY_DIR.exists():
        return []

    entries = []
    for path in sorted(HISTORY_DIR.glob("*.md"), reverse=True):
        title = _title_from_filename(path.stem)
        url = _read_url_from_frontmatter(path)
        entries.append({"title": title, "url": url, "path": path})
    return entries


def load_article_content(path: Path) -> str:
    """Load article content from a markdown file, stripping YAML frontmatter.

    Returns the markdown content after the closing ``---`` marker.
    If no frontmatter is found, returns the full text.
    """
    text = path.read_text()
    if text.startswith("---\n"):
        end = text.find("\n---\n", 3)
        if end != -1:
            return text[end + 5:]
    return text


def _sanitize_title(title: str) -> str:
    """Strip special characters and collapse whitespace to hyphens."""
    clean = re.sub(r"[^\w\s-]", "", title)
    clean = re.sub(r"\s+", "-", clean.strip())
    return clean


def _title_from_filename(stem: str) -> str:
    """Extract a human-readable title from a history filename stem."""
    if len(stem) > 7 and stem[6] == "-" and stem[:6].isdigit():
        title_part = stem[7:]
    else:
        title_part = stem
    return title_part.replace("-", " ")


def _read_url_from_frontmatter(path: Path) -> str:
    """Read the URL from a markdown file's YAML frontmatter."""
    try:
        text = path.read_text()
    except (OSError, UnicodeDecodeError):
        return ""
    if text.startswith("---\n"):
        end = text.find("\n---\n", 3)
        if end != -1:
            frontmatter = text[4:end]
            for line in frontmatter.split("\n"):
                if line.startswith("url: "):
                    return line[5:].strip()
    return ""
