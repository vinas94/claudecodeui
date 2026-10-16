# Chat flickers and jumps when the scrollbar appears or after a fork

## Problem

1. New chat: once the transcript gets long enough to scroll, the scrollbar appears and
   the whole transcript re-renders and flickers.
2. Fork from here: lots of flicker and the scrollbar jumps around while the forked
   session opens.

## Likely causes (not verified yet)

1. Scrollbar appearing: the transcript container
   (`src/modules/chat/transcript/ChatMessagesPane.tsx`, `.chat-messages-pane`,
   `overflow-y-auto`) reserves no space for the scrollbar. When macOS shows a classic
   scrollbar (a mouse is connected, or "Show scroll bars: Always"), it takes width the
   moment content overflows, every message reflows to the narrower width, and the lazy
   message rows (`LazyMessageRow.tsx`) re-measure. Candidate fix: `scrollbar-gutter:
   stable` on `.chat-messages-pane`.
2. Fork: the fork navigates to a new session, which remounts the transcript, loads the
   messages and then scrolls to the bottom, while lazy rows measure their heights.
   Needs a look at the load/scroll sequence in `ChatInterface.tsx` / `useSessionStore.ts`
   and how the scroll position is restored on session switch.

## Check

- Reproduce in CloudCLI.app and in Safari/Chrome at http://127.0.0.1:3001, to tell
  CloudCLI bugs from WebKit-window specifics.
