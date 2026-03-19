"""Tests for the history persistence module."""

import shutil
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

import pytest

from articles.history import (
    HISTORY_DIR,
    _sanitize_title,
    _title_from_filename,
    list_history,
    load_article_content,
    save_article,
)


@pytest.fixture
def tmp_history(tmp_path, monkeypatch):
    """Redirect HISTORY_DIR to a temp directory for test isolation."""
    monkeypatch.setattr("articles.history.HISTORY_DIR", tmp_path)
    return tmp_path


# --- save_article tests ---


def test_save_creates_md_file(tmp_history):
    """save_article returns a Path that exists and has .md suffix."""
    path = save_article("https://example.com", "Test", "content")
    assert path.exists()
    assert path.suffix == ".md"


def test_save_filename_format(tmp_history):
    """Filename follows YYMMDD-Title.md format with mocked date."""
    with patch("articles.history.datetime") as mock_dt:
        mock_dt.now.return_value = datetime(2026, 3, 19)
        mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw)
        path = save_article("https://example.com", "Test Article", "content")
    assert path.name == "260319-Test-Article.md"


def test_save_includes_url_frontmatter(tmp_history):
    """Saved file starts with YAML frontmatter containing the URL."""
    path = save_article("https://example.com", "Test", "content")
    text = path.read_text()
    assert text.startswith("---\n")
    assert "url: https://example.com" in text


def test_save_content_after_frontmatter(tmp_history):
    """Saved file contains original content after frontmatter block."""
    path = save_article("https://example.com", "Test", "# Hello\n\nWorld")
    text = path.read_text()
    assert "# Hello\n\nWorld" in text


def test_save_overwrites_duplicate_url(tmp_history):
    """Saving the same URL twice leaves only 1 file with the second content."""
    save_article("https://a.com", "First Title", "first content")
    save_article("https://a.com", "Second Title", "second content")
    files = list(tmp_history.glob("*.md"))
    assert len(files) == 1
    assert "second content" in files[0].read_text()


def test_save_empty_title_uses_fallback(tmp_history):
    """Empty title string results in 'untitled' in the filename."""
    path = save_article("https://example.com", "", "content")
    assert "untitled" in path.name


def test_save_long_title_truncated(tmp_history):
    """Title longer than 50 chars is truncated in the filename."""
    path = save_article("https://example.com", "A" * 100, "content")
    # Stem minus 7-char date prefix and hyphen
    title_part = path.stem[7:]
    assert len(title_part) <= 50


def test_save_special_chars_stripped(tmp_history):
    """Special characters are removed from the filename."""
    path = save_article("https://example.com", "Hello, World! @#$", "content")
    assert "Hello-World" in path.name


# --- list_history tests ---


def test_list_empty_no_directory(tmp_history):
    """list_history returns [] when the history directory doesn't exist."""
    shutil.rmtree(tmp_history)
    assert list_history() == []


def test_list_returns_entries_with_keys(tmp_history):
    """list_history returns dicts with title, url, and path keys."""
    save_article("https://a.com", "Article A", "content a")
    save_article("https://b.com", "Article B", "content b")
    entries = list_history()
    assert len(entries) == 2
    for entry in entries:
        assert "title" in entry
        assert "url" in entry
        assert "path" in entry


def test_list_most_recent_first(tmp_history):
    """Entries are sorted with newer filenames first."""
    (tmp_history / "260318-Older.md").write_text("---\nurl: https://old.com\n---\n\nold")
    (tmp_history / "260319-Newer.md").write_text("---\nurl: https://new.com\n---\n\nnew")
    entries = list_history()
    assert entries[0]["title"] == "Newer"
    assert entries[1]["title"] == "Older"


# --- load_article_content tests ---


def test_load_strips_frontmatter(tmp_history):
    """Loaded content does not contain frontmatter markers or URL."""
    path = save_article("https://example.com", "Test", "# Hello\n\nWorld")
    content = load_article_content(path)
    assert "---" not in content
    assert "url:" not in content


def test_load_returns_original_content(tmp_history):
    """Loaded content matches what was passed to save_article."""
    original = "# Hello\n\nWorld"
    path = save_article("https://example.com", "Test", original)
    content = load_article_content(path)
    assert content == original


# --- private helper tests ---


def test_sanitize_strips_special_chars():
    """_sanitize_title removes special characters and collapses whitespace."""
    assert _sanitize_title("Hello, World!") == "Hello-World"


def test_title_from_filename():
    """_title_from_filename extracts human-readable title from stem."""
    assert _title_from_filename("260319-How-CSS-Grid-Works") == "How CSS Grid Works"
