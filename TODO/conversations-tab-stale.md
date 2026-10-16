# Conversations tab doesn't show new sessions until you switch tabs

## Problem

With the sidebar on the Conversations tab, forking a session (or any new session)
doesn't add it to the list. It only appears after switching to another tab and back.

## Cause

`src/modules/sidebar/hooks/useSidebarController.ts` loads the list once per tab switch:
the effect around line 315 calls `reloadRecentConversations()` only when `searchMode`
or the search query changes. Nothing reloads it when sessions change, unlike the
Projects tab, which follows the live project/session updates.

## Wanted

Reload (or patch in) the recent-conversations list when a session is created, forked,
renamed, archived or gets new activity, e.g. on the same `session_upserted` events
`useProjectsState.ts` already handles, debounced.
