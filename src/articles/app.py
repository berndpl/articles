"""Textual TUI for distraction-free article reading."""

import re

from textual.actions import SkipAction
from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import VerticalScroll
from textual.css.query import NoMatches
from textual.events import Paste
from textual.widgets import Footer, OptionList, Static

from articles.extractor import extract_url
from articles.history import list_history, load_article_content, save_article

URL_PATTERN = re.compile(r"https?://[^\s<>\"]+")


class ArticlesApp(App):
    """Distraction-free article reader for the terminal."""

    CSS = """
    Screen {
        background: #11111b;
    }
    #status-bar {
        dock: top;
        height: 1;
        background: #181825;
        color: #cdd6f4;
        padding: 0 2;
    }
    #history {
        align-horizontal: center;
        background: #11111b;
        padding: 1 0;
    }
    #history-list {
        width: 100%;
        max-width: 88;
        height: auto;
        min-height: 7;
        background: #181825;
        color: #cdd6f4;
        border: tall #313244;
    }
    #content {
        display: none;
        align-horizontal: center;
        background: #11111b;
        scrollbar-size: 0 0;
    }
    #article,
    #article-shell {
        max-width: 88;
        margin: 0;
        padding: 1 2;
    }
    """

    TITLE = "articles"

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("h", "back", "History"),
        Binding("left", "back", "", show=False),
        Binding("up", "reader_scroll_up", "", show=False),
        Binding("down", "reader_scroll_down", "", show=False),
        Binding("super+up,meta+up", "reader_page_up", "", show=False),
        Binding("super+down,meta+down", "reader_page_down", "", show=False),
    ]

    def __init__(self, url: str | None = None):
        super().__init__()
        self.theme = "catppuccin-mocha"
        self._initial_url = url
        self._history_entries: list[dict] = []

    def compose(self) -> ComposeResult:
        yield Static("", id="status-bar")
        with VerticalScroll(id="history"):
            yield OptionList(id="history-list")
        with VerticalScroll(id="content"):
            yield Static("", id="article-shell")
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
        self._history_entries = list_history(include_url=False)
        history_container = self.query_one("#history", VerticalScroll)
        history_widget = self.query_one("#history-list", OptionList)
        history_widget.clear_options()
        for entry in self._history_entries:
            history_widget.add_option(entry["title"])
        history_widget.highlighted = 0 if self._history_entries else None
        history_container.display = True
        history_container.scroll_home()
        history_widget.focus()
        self.query_one("#content").display = False
        self.query_one("#status-bar", Static).update(
            "Paste a URL to start reading"
        )
        self.title = "articles"

    def on_option_list_option_selected(
        self, event: OptionList.OptionSelected
    ) -> None:
        """Open selected article from history."""
        try:
            idx = event.option_index
        except AttributeError:
            idx = getattr(event, "index", None)
        if not isinstance(idx, int):
            idx = getattr(event, "index", None)
        if isinstance(idx, int) and idx < len(self._history_entries):
            entry = self._history_entries[idx]
            content = load_article_content(entry["path"])
            self._display_article(content, entry["title"])

    def _get_article_widget(self, content: str):
        """Upgrade the placeholder article view to Markdown on first use."""
        try:
            return self.query_one("#article")
        except NoMatches:
            from textual.widgets import Markdown

            markdown = Markdown(content, id="article")
            self.query_one("#article-shell", Static).remove()
            self.query_one("#content", VerticalScroll).mount(markdown)
            return markdown

    def _display_article(self, content: str, title: str) -> None:
        """Switch to article view with given content."""
        self.query_one("#history", VerticalScroll).display = False
        content_view = self.query_one("#content", VerticalScroll)
        content_view.display = True
        self._get_article_widget(content).update(content)
        self.title = title
        content_view.scroll_home()
        content_view.focus()
        self.query_one("#status-bar", Static).update("")

    def _get_reader_view(self) -> VerticalScroll:
        """Return the article scroll container when the reader is visible."""
        content_view = self.query_one("#content", VerticalScroll)
        if not content_view.display:
            raise SkipAction()
        return content_view

    def action_back(self) -> None:
        """Return to history list (bound to 'h' and left arrow)."""
        self._show_history()

    def action_reader_scroll_up(self) -> None:
        """Scroll the reader up one step when article view is active."""
        self._get_reader_view().scroll_up(animate=False)

    def action_reader_scroll_down(self) -> None:
        """Scroll the reader down one step when article view is active."""
        self._get_reader_view().scroll_down(animate=False)

    def action_reader_page_up(self) -> None:
        """Page the reader up when article view is active."""
        self._get_reader_view().scroll_page_up(animate=False)

    def action_reader_page_down(self) -> None:
        """Page the reader down when article view is active."""
        self._get_reader_view().scroll_page_down(animate=False)

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
