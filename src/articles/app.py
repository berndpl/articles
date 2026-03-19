"""Textual TUI for distraction-free article reading."""

import re

from textual import work
from textual.app import App, ComposeResult
from textual.containers import VerticalScroll
from textual.events import Paste
from textual.widgets import Footer, Markdown, OptionList, Static

from articles.extractor import extract_url
from articles.history import list_history, load_article_content, save_article

URL_PATTERN = re.compile(r"https?://[^\s<>\"]+")


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
    #history-list {
        width: 100%;
        height: 1fr;
    }
    #content {
        display: none;
        align-horizontal: center;
        scrollbar-size: 0 0;
    }
    #article {
        max-width: 88;
        margin: 0;
        padding: 1 2;
    }
    """

    TITLE = "articles"

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("h", "back", "History"),
        ("left", "back", ""),
    ]

    def __init__(self, url: str | None = None):
        super().__init__()
        self.theme = "catppuccin-mocha"
        self._initial_url = url
        self._history_entries: list[dict] = []

    def compose(self) -> ComposeResult:
        yield Static("", id="status-bar")
        yield OptionList(id="history-list")
        with VerticalScroll(id="content"):
            yield Markdown(id="article")
        yield Footer()

    def on_mount(self) -> None:
        if self._initial_url:
            self.load_article(self._initial_url)
        else:
            self._show_history()

    def on_paste(self, event: Paste) -> None:
        match = URL_PATTERN.search(event.text)
        if match:
            self.load_article(match.group())

    def _show_history(self) -> None:
        """Populate and show the history list, hide article content."""
        self._history_entries = list_history()
        history_widget = self.query_one("#history-list", OptionList)
        history_widget.clear_options()
        for entry in self._history_entries:
            history_widget.add_option(entry["title"])
        history_widget.display = True
        self.query_one("#content").display = False
        self.query_one("#status-bar", Static).update(
            "Paste a URL to start reading"
        )
        self.title = "articles"

    def on_option_list_option_selected(
        self, event: OptionList.OptionSelected
    ) -> None:
        """Open selected article from history."""
        idx = event.index
        if idx < len(self._history_entries):
            entry = self._history_entries[idx]
            content = load_article_content(entry["path"])
            self._display_article(content, entry["title"])

    def _display_article(self, content: str, title: str) -> None:
        """Switch to article view with given content."""
        self.query_one("#history-list").display = False
        self.query_one("#content").display = True
        self.query_one("#article", Markdown).update(content)
        self.title = title
        self.query_one("#content", VerticalScroll).scroll_home()
        self.query_one("#status-bar", Static).update("")

    def action_back(self) -> None:
        """Return to history list (bound to 'h' and left arrow)."""
        self._show_history()

    @work(thread=True, exclusive=True, group="loader")
    def load_article(self, url: str) -> None:
        """Extract and display article in background thread."""
        # Step 1: Fetching
        self.call_from_thread(
            self.query_one("#status-bar", Static).update,
            f"Fetching {url}...",
        )
        try:
            content = extract_url(url)

            self.call_from_thread(
                self.query_one("#status-bar", Static).update,
                "Rendering...",
            )

            # Extract title from first markdown heading, fallback to "articles"
            title = "articles"
            for line in content.split("\n"):
                if line.startswith("# "):
                    title = line[2:].strip()
                    break

            # Save to history
            save_article(url, title, content)

            # Switch to article view
            self.call_from_thread(self._display_article, content, title)
        except (ValueError, RuntimeError) as exc:
            self.call_from_thread(
                self.notify, str(exc), severity="error", timeout=5,
            )
        finally:
            self.call_from_thread(
                self.query_one("#status-bar", Static).update, "",
            )
