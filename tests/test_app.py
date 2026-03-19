"""Tests for the articles TUI application."""

import pytest
from unittest.mock import patch

from articles.app import ArticlesApp


@pytest.mark.asyncio
async def test_app_shows_welcome_without_url():
    """Launch without URL shows welcome screen."""
    app = ArticlesApp()
    async with app.run_test() as pilot:
        md = pilot.app.query_one("#article")
        assert "Paste a URL" in md._markdown


@pytest.mark.asyncio
async def test_app_loads_article_with_initial_url():
    """Launch with URL loads article content."""
    mock_md = "# Test Article\n\nSome content here."
    with patch("articles.app.extract_url", return_value=mock_md):
        app = ArticlesApp(url="https://example.com")
        async with app.run_test() as pilot:
            await pilot.pause(1.0)
            md = pilot.app.query_one("#article")
            assert "Test Article" in md._markdown


@pytest.mark.asyncio
async def test_app_has_catppuccin_mocha_theme():
    """App uses Catppuccin Mocha built-in theme."""
    app = ArticlesApp()
    async with app.run_test() as pilot:
        assert pilot.app.theme == "catppuccin-mocha"
