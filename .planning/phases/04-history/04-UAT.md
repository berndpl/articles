---
status: testing
phase: 04-history
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md]
started: "2026-03-19T12:44:00.000Z"
updated: "2026-03-19T12:44:00.000Z"
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: First launch — empty history
expected: |
  Launch `articles` with no prior history files. The screen should be mostly blank
  with a paste hint visible in the status bar / footer area. No crash, no error.
awaiting: user response

## Tests

### 1. First launch — empty history
expected: Launch `articles` with no prior history files. Screen is blank with a paste hint in the status bar. No crash, no error.
result: [pending]

### 2. Read an article and check history save
expected: Paste or provide a URL. Article loads and displays in the reader. A `.md` file appears in `src/articles/history/` with `YYMMDD-Title.md` naming format and the article content inside.
result: [pending]

### 3. History list shows saved articles
expected: After reading at least one article, press `h` or left arrow to return to history. The history list shows the article title(s) you've read, most recent first.
result: [pending]

### 4. Re-open article from history
expected: From the history list, use arrow keys to highlight an entry and press Enter. The article content loads in the reader — no network fetch, loaded from the saved `.md` file.
result: [pending]

### 5. Back navigation (h / left arrow)
expected: While reading an article, press `h` or left arrow. You return to the history list. The article you were reading is still in the list.
result: [pending]

### 6. Paste URL from history screen
expected: While on the history list screen, paste a URL. The article loads immediately in the reader — paste works from the history screen, not just from the reader.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0

## Gaps

[none yet]
