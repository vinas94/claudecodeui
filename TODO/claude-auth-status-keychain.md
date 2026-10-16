# Settings shows Claude as "Disconnected" on macOS while logged in

## Problem

Settings → Claude → Account shows "Disconnected / Not connected" with "Claude CLI is not
authenticated. Run claude /login or configure ANTHROPIC_API_KEY", even right after a
successful `/login`. Chats work fine.

## Cause

`server/modules/providers/list/claude/claude-auth.provider.ts` (`checkCredentials`,
around line 114) only looks for `~/.claude/.credentials.json`, which is where Claude
Code keeps the login on Linux. On macOS Claude Code stores it in the Keychain (item
"Claude Code-credentials"), so the file doesn't exist and the check always fails.

The status only feeds the Settings and onboarding views; chats don't use it.

## Wanted

On macOS, when the credentials file is missing, check the Keychain:
`security find-generic-password -s "Claude Code-credentials"` (existence is enough to
report "Connected"; reading the secret isn't needed). Keep the file check for Linux.
