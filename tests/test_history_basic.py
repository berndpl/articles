"""Basic smoke tests for history module — TDD RED phase for Task 1."""

from pathlib import Path


def test_history_module_imports():
    """Verify all public exports are importable."""
    from articles.history import save_article, list_history, load_article_content, HISTORY_DIR
    assert callable(save_article)
    assert callable(list_history)
    assert callable(load_article_content)
    assert isinstance(HISTORY_DIR, Path)


def test_save_creates_file(tmp_path, monkeypatch):
    """save_article creates a .md file."""
    from articles.history import save_article
    monkeypatch.setattr("articles.history.HISTORY_DIR", tmp_path)
    result = save_article("https://example.com", "Test", "# Content")
    assert result.exists()
    assert result.suffix == ".md"


def test_list_empty_dir(tmp_path, monkeypatch):
    """list_history returns [] when directory doesn't exist."""
    import shutil
    from articles.history import list_history
    monkeypatch.setattr("articles.history.HISTORY_DIR", tmp_path)
    shutil.rmtree(tmp_path)
    assert list_history() == []


def test_load_strips_frontmatter(tmp_path, monkeypatch):
    """load_article_content returns content without frontmatter."""
    from articles.history import save_article, load_article_content
    monkeypatch.setattr("articles.history.HISTORY_DIR", tmp_path)
    path = save_article("https://example.com", "Test", "# Hello\n\nWorld")
    content = load_article_content(path)
    assert "---" not in content
    assert "url:" not in content
    assert "# Hello" in content
