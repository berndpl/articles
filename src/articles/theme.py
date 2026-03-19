"""Cappuccino/mocha theme for the articles TUI."""

from textual.theme import Theme

CAPPUCCINO = Theme(
    name="cappuccino",
    primary="#D2691E",       # cinnamon — headers, primary accents
    secondary="#8B4513",     # saddle brown — secondary elements
    background="#2C1810",    # dark mocha base
    foreground="#F5DEB3",    # cream/wheat text
    surface="#3E2723",       # slightly lighter brown — surfaces
    panel="#4E342E",         # header/footer chrome — blends with mocha
    accent="#CD853F",        # burnt orange — links, highlights
    warning="#DEB887",       # burlywood — warnings
    error="#CD5C5C",         # indian red — errors
    success="#8FBC8F",       # dark sea green — success
    dark=True,
    variables={
        "markdown-h1-color": "#D2691E",     # cinnamon headers
        "markdown-h1-text-style": "bold",
        "markdown-h2-color": "#CD853F",     # burnt orange sub-headers
        "markdown-h2-text-style": "bold",
        "footer-background": "#3E2723",     # surface brown — blends
        "scrollbar": "#5D4037",             # medium brown scrollbar
        "scrollbar-background": "#2C1810",  # matches base background
    },
)
