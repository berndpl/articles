"""w3m-based URL extraction — converts web pages to plain text."""

import subprocess


def extract_url(url: str) -> str:
    """Fetch and extract a URL as plain text using w3m.

    Args:
        url: The URL to fetch. Must not be empty.

    Returns:
        Plain text content of the page.

    Raises:
        ValueError: If url is empty.
        RuntimeError: If w3m fails (non-zero exit code or not installed).
    """
    if not url:
        raise ValueError("URL must not be empty")

    try:
        result = subprocess.run(
            ["w3m", "-dump", url],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        raise RuntimeError("w3m failed: w3m is not installed. Run: brew install w3m")
    except subprocess.TimeoutExpired:
        raise RuntimeError("w3m failed: request timed out after 30 seconds")

    if result.returncode != 0:
        stderr = result.stderr.strip()
        raise RuntimeError(f"w3m failed: {stderr or 'non-zero exit code'}")

    return result.stdout
