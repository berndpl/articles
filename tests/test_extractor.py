"""Tests for the w3m extraction function."""

import subprocess
from unittest.mock import MagicMock, patch

import pytest

from articles.extractor import extract_url


def test_extract_url_returns_nonempty_string():
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = "Example Domain\nThis domain is for use in examples."
    mock_result.stderr = ""
    with patch("articles.extractor.subprocess.run", return_value=mock_result):
        output = extract_url("https://example.com")
    assert isinstance(output, str)
    assert len(output) > 0


def test_extract_url_output_contains_page_text():
    mock_result = MagicMock()
    mock_result.returncode = 0
    mock_result.stdout = "Example Domain\nThis domain is for use in examples."
    mock_result.stderr = ""
    with patch("articles.extractor.subprocess.run", return_value=mock_result):
        output = extract_url("https://example.com")
    assert "Example Domain" in output


def test_extract_url_raises_value_error_on_empty_url():
    with pytest.raises(ValueError, match="URL must not be empty"):
        extract_url("")


def test_extract_url_raises_runtime_error_when_w3m_not_installed():
    with patch(
        "articles.extractor.subprocess.run",
        side_effect=FileNotFoundError,
    ):
        with pytest.raises(RuntimeError, match="w3m failed"):
            extract_url("https://example.com")


def test_extract_url_raises_runtime_error_on_nonzero_exit():
    mock_result = MagicMock()
    mock_result.returncode = 1
    mock_result.stdout = ""
    mock_result.stderr = "connect error"
    with patch("articles.extractor.subprocess.run", return_value=mock_result):
        with pytest.raises(RuntimeError, match="w3m failed"):
            extract_url("https://example.com")
