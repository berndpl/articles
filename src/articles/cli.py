"""CLI entry point — launches the articles TUI."""

import sys

from articles.app import ArticlesApp


def main() -> None:
    """Main entry point for the `articles` CLI command.

    Usage:
        articles            # launches TUI with welcome screen
        articles <url>      # launches TUI and immediately loads the URL
    """
    url = sys.argv[1] if len(sys.argv) > 1 else None
    app = ArticlesApp(url=url)
    app.run()


if __name__ == "__main__":
    main()
