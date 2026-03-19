"""Tests for the articles TUI application."""

import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from articles.app import ArticlesApp
from textual.widgets import OptionList


@pytest.mark.asyncio
async def test_app_shows_history_on_launch():
    """Launch without URL shows history list with paste hint."""
    with patch("articles.app.list_history", return_value=[]):
        app = ArticlesApp()
        async with app.run_test() as pilot:
            status = pilot.app.query_one("#status-bar")
            assert "Paste a URL" in str(status._Static__content)


@pytest.mark.asyncio
async def test_app_loads_article_with_initial_url():
    """Launch with URL loads article content and saves to history."""
    mock_md = "# Test Article\n\nSome content here."
    with patch("articles.app.extract_url", return_value=mock_md), \
         patch("articles.app.save_article") as mock_save, \
         patch("articles.app.list_history", return_value=[]):
        app = ArticlesApp(url="https://example.com")
        async with app.run_test() as pilot:
            await pilot.pause(1.0)
            md = pilot.app.query_one("#article")
            assert "Test Article" in md._markdown
            mock_save.assert_called_once_with(
                "https://example.com", "Test Article", mock_md
            )


@pytest.mark.asyncio
async def test_app_has_catppuccin_mocha_theme():
    """App uses Catppuccin Mocha built-in theme."""
    with patch("articles.app.list_history", return_value=[]):
        app = ArticlesApp()
        async with app.run_test() as pilot:
            assert pilot.app.theme == "catppuccin-mocha"


@pytest.mark.asyncio
async def test_app_displays_history_entries():
    """History entries appear in the OptionList on launch."""
    mock_entries = [
        {"title": "First Article", "url": "https://a.com", "path": Path("/tmp/a.md")},
        {"title": "Second Article", "url": "https://b.com", "path": Path("/tmp/b.md")},
    ]
    with patch("articles.app.list_history", return_value=mock_entries):
        app = ArticlesApp()
        async with app.run_test() as pilot:
            option_list = pilot.app.query_one("#history-list")
            assert option_list.option_count == 2


@pytest.mark.asyncio
async def test_app_opens_history_entry():
    """Selecting a history entry opens it in the reader."""
    mock_entries = [
        {"title": "Test Article", "url": "https://a.com", "path": Path("/tmp/a.md")},
    ]
    with patch("articles.app.list_history", return_value=mock_entries), \
         patch("articles.app.load_article_content", return_value="# Test Article\n\nContent") as mock_load:
        app = ArticlesApp()
        async with app.run_test() as pilot:
            # Directly call the handler with a mock event to test integration
            mock_event = MagicMock()
            mock_event.index = 0
            pilot.app.on_option_list_option_selected(mock_event)
            await pilot.pause(0.5)
            mock_load.assert_called_once_with(Path("/tmp/a.md"))
            md = pilot.app.query_one("#article")
            assert "Test Article" in md._markdown


@pytest.mark.asyncio
async def test_app_back_returns_to_history():
    """Pressing 'h' from article view returns to history list."""
    mock_md = "# Test Article\n\nContent"
    with patch("articles.app.extract_url", return_value=mock_md), \
         patch("articles.app.save_article"), \
         patch("articles.app.list_history", return_value=[]):
        app = ArticlesApp(url="https://example.com")
        async with app.run_test() as pilot:
            await pilot.pause(1.0)
            await pilot.press("h")
            await pilot.pause(0.5)
            history_list = pilot.app.query_one("#history-list")
            assert history_list.display is True


@pytest.mark.asyncio
async def test_app_no_welcome_md():
    """WELCOME_MD constant no longer exists in app module."""
    import articles.app
    assert not hasattr(articles.app, "WELCOME_MD")
