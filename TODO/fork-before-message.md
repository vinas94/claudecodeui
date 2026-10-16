# Fork from here: fork before the message, prefill the composer

## Problem

"Fork from here" on a user message copies the conversation up to and including that
message. The fork ends on an unanswered prompt, so you have to type a new one.

- Button: `src/modules/chat/transcript/MessageComponent.tsx` (`onForkFromMessage`)
- Handler: `src/modules/chat/ChatInterface.tsx` (`handleForkFromMessage` sends
  `upToAnchorId: message.transcriptAnchorId`)
- Server: `server/modules/providers/list/claude/claude-fork.provider.ts` passes it to the
  SDK's `forkSession` as `upToMessageId`, which is inclusive.

## Wanted

Same as Claude Code / Pi: fork just before the message and put its text in the new
session's composer, so you edit and send.

- Fork up to the row before the clicked message. For the first message, that is a new
  empty session with the text prefilled.
- Save the message text as the forked session's draft (existing `session_drafts` table)
  before navigating to it.

Result:
- Edit & resend: rewind this session to before the message, edit it.
- Fork from here: same, in a new session; the original stays untouched.
