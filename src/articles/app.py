"""Textual TUI for distraction-free article reading."""

import re

from textual import work
from textual.app import App, ComposeResult
from textual.containers import VerticalScroll
from textual.events import Paste
from textual.widgets import Footer, Markdown, Static

from articles.extractor import extract_url
from articles.theme import CAPPUCCINO

URL_PATTERN = re.compile(r"https?://[^\s<>\"]+")

WELCOME_MD = """\
# articles

*Paste a URL to start reading*
"""


class ArticlesApp(App):
    """Distraction-free article reader for the terminal."""

    CSS = """
    #status-bar {
        dock: top;
        height: 1;
        background: $panel;
        color: $foreground;
        padding: 0 2;
    }
    #content {
        align-horizontal: center;
        scrollbar-size: 0 0;
    }
    #article {
        max-width: 88;
        margin: 0;
        padding: 1 2;
    }
    #welcome {
        content-align: center middle;
        width: 100%;
        height: 100%;
    }
    """

    TITLE = "articles"

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("n", "new_url", "New URL"),
    ]

    def __init__(self, url: str | None = None):
        super().__init__()
        self.register_theme(CAPPUCCINO)
        self.theme = "cappuccino"
        self._initial_url = url

    def compose(self) -> ComposeResult:
        yield Static("", id="status-bar")
        with VerticalScroll(id="content"):
            yield Markdown(id="article")
        yield Footer()

    def on_mount(self) -> None:
        if self._initial_url:
            self.load_article(self._initial_url)
        else:
            self.query_one("#article", Markdown).update(WELCOME_MD)

    def on_paste(self, event: Paste) -> None:
        match = URL_PATTERN.search(event.text)
        if match:
            self.load_article(match.group())

    def action_new_url(self) -> None:
        """Reset to welcome screen (bound to 'n' key)."""
        self.query_one("#article", Markdown).update(WELCOME_MD)
        self.query_one("#status-bar", Static).update("")
        self.title = "articles"
        self.query_one("#content", VerticalScroll).scroll_home()

    @work(thread=True, exclusive=True, group="loader")
    def load_article(self, url: str) -> None:
        """Extract and display article in background thread."""
        # Step 1: Fetching
        self.call_from_thread(
            self.query_one("#status-bar", Static).update,
            f"Fetching {url}...",
        )
        try:
            # Step 2: Extracting (trafilatura does fetch+extract together,
            # but we show progress steps for user confidence)
            content = extract_url(url)

            # Step 3: Rendering
            self.call_from_thread(
                self.query_one("#status-bar", Static).update,
                "Rendering...",
            )
            self.call_from_thread(
                self.query_one("#article", Markdown).update,
                content,
            )

            # Extract title from first markdown heading, fallback to "articles"
            title = "articles"
            for line in content.split("\n"):
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
            self.call_from_thread(setattr, self, "title", title)

            # Scroll to top for new article
            self.call_from_thread(
                self.query_one("#content", VerticalScroll).scroll_home,
            )
        except (ValueError, RuntimeError) as exc:
            # Error: show notification, keep current article visible
            self.call_from_thread(
                self.notify, str(exc), severity="error", timeout=5,
            )
        finally:
            # Clear status bar
            self.call_from_thread(
                self.query_one("#status-bar", Static).update, "",
            )
