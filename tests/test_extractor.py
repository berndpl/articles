"""Tests for the trafilatura-based extraction function."""

from unittest.mock import patch

import pytest

from articles.extractor import extract_url

MOCK_HTML = "<html><body><article><h1>Test Title</h1><p>Content with <b>bold</b> and <a href='https://link.com'>a link</a>.</p></article></body></html>"
MOCK_MARKDOWN = "# Test Title\n\nContent with **bold** and [a link](https://link.com)."


def test_extract_url_returns_markdown_with_headers():
    with patch("articles.extractor.trafilatura.fetch_url", return_value=MOCK_HTML):
        with patch("articles.extractor.trafilatura.extract", return_value=MOCK_MARKDOWN):
            output = extract_url("https://example.com")
    assert "# " in output


def test_extract_url_returns_markdown_with_links():
    with patch("articles.extractor.trafilatura.fetch_url", return_value=MOCK_HTML):
        with patch("articles.extractor.trafilatura.extract", return_value=MOCK_MARKDOWN):
            output = extract_url("https://example.com")
    assert "[" in output and "](" in output


def test_extract_url_raises_value_error_on_empty_url():
    with pytest.raises(ValueError, match="URL must not be empty"):
        extract_url("")


def test_extract_url_raises_runtime_error_on_fetch_failure():
    with patch("articles.extractor.trafilatura.fetch_url", return_value=None):
        with pytest.raises(RuntimeError, match="Failed to fetch"):
            extract_url("https://bad.com")


def test_extract_url_raises_runtime_error_on_no_content():
    with patch("articles.extractor.trafilatura.fetch_url", return_value=MOCK_HTML):
        with patch("articles.extractor.trafilatura.extract", return_value=None):
            with pytest.raises(RuntimeError, match="No article content"):
                extract_url("https://empty.com")
