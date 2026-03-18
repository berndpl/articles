"""CLI entry point for the articles terminal reader."""

import sys

from articles.extractor import extract_url


def main() -> None:
    """Main entry point for the `articles` CLI command.

    Usage:
        articles                  # prints usage help
        articles <url>            # fetches URL and prints extracted text
    """
    if len(sys.argv) < 2:
        print("Usage: articles <url>")
        print("Example: articles https://example.com")
        sys.exit(0)

    url = sys.argv[1]

    try:
        content = extract_url(url)
        print(content)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
