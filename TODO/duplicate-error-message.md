# API errors show twice

## Problem

When a turn fails with an API error, the transcript shows it twice:

1. As a "Claude" message: "API Error: 400 Claude Code 2.1.226 does not support this
   model; version 2.1.251 or newer is required. ..."
2. Right below as a red "Error": "Claude Code returned an error result: API Error: 400
   ..." (same text with a prefix).

## Likely cause (not verified)

Claude Code writes the API error into the transcript as an assistant message, and the
run's final `result` (with `is_error`) is also turned into a separate error row by
CloudCLI (`server/modules/providers/list/claude/claude-runtime.provider.js`, the
"returned an error result" path).

## Wanted

Show the error once: keep the red Error row and hide the duplicate assistant message
(or the reverse), matching on the same error text.
