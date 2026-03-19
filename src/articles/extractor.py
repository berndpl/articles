"""Article extraction — fetches web pages and converts to markdown."""


def extract_url(url: str) -> str:
    """Fetch a URL and extract its article content as markdown.

    Args:
        url: The URL to fetch. Must not be empty.

    Returns:
        Markdown-formatted article content with headers, bold, and links.

    Raises:
        ValueError: If url is empty.
        RuntimeError: If fetching fails or no article content is found.
    """
    import trafilatura

    if not url:
        raise ValueError("URL must not be empty")

    downloaded = trafilatura.fetch_url(url)
    if downloaded is None:
        raise RuntimeError(f"Failed to fetch: {url}")

    result = trafilatura.extract(
        downloaded,
        output_format="markdown",
        include_links=True,
    )
    if not result:
        raise RuntimeError(f"No article content found at: {url}")

    return result
