# Cmd+F: find within the current session

## Problem

Cmd+F does nothing in CloudCLI.app. Wanted: search inside the active session's
conversation only (not a global search; the sidebar's ⌘K search already covers all
conversations).

## Why not a page-level find bar

The transcript renders only rows near the viewport; off-screen messages are swapped for
fixed-height placeholders (`src/modules/chat/transcript/LazyMessageRow.tsx`). A
browser/WebKit-style DOM find (like the mobile.de launcher's find bar) would miss most
messages of a long session.

## Fix (web side, in the chat module)

- Cmd+F while a session is open shows a small find bar over the transcript (field,
  "3 / 12" count, ↑/↓, Esc closes). Works in a browser tab too.
- Search the session's loaded messages (the message list in the chat store, not the
  DOM), including older pages if the transcript is paginated.
- Next/previous scrolls the hit's row into view, lets it render, and highlights the
  match.
- Inside the code editor, Cmd+F stays the editor's own search.
- Launcher: make sure Cmd+F reaches the page (no conflicting menu item).
