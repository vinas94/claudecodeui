# Useless error when the project folder no longer exists

## Problem

Chatting in a project whose folder was deleted (old worktrees, removed scratch dirs)
fails with:

> Claude Code native binary at /opt/homebrew/bin/claude exists but failed to launch.

The binary is fine. Spawning fails because the working directory is missing, and the
SDK reports that as a launch failure. CloudCLI passes the message through unchanged
(`server/modules/providers/list/claude/claude-runtime.provider.js`, `SDK query error`
around line 1048; `cwd` set in `mapCliOptionsToSDK` around line 236).

These projects show up in the first place because CloudCLI lists every folder from the
Claude Code history (`~/.claude/projects`), including deleted ones.

## Wanted

1. Before starting a run, check that `cwd` exists. If not, fail with a clear message:
   "Project folder no longer exists: <path>".
2. In the project list, mark or hide projects whose folder is gone, so they are not
   offered for new chats.
