# Archive tab flicker, and Archive vs Running tabs look different

## 1. "Loading archive..." flashes

Opening the Archive tab shows "Loading archive..." for a split second, then "No
archived items". The archive is a tiny local list, so the loading state only causes a
flash.

- `src/modules/sidebar/SidebarContent.tsx`, loading state around line 436, empty state
  around line 464.

Wanted: the same rule the Conversations tab already uses
(`SidebarRecentConversations.tsx` around line 67): show a placeholder only while
loading with nothing loaded yet, and keep the current list during refetches. Archive
currently shows "Loading archive..." on every load (`SidebarContent.tsx` around line
428), even when it already has data. Use a skeleton like Conversations instead of the
text card.

## 2. Archive and Running tabs have different styles

Same kind of tab, same kind of empty state, different looks:

- Empty state: Archive is a dashed card with a white icon tile; Running has no card and
  a grey icon tile. (`SidebarContent.tsx`, Running around line 401, Archive around
  line 464.)
- Selected tab icon: Archive gets a white filled background; Running gets an outlined,
  tinted box.

Wanted: one shared empty-state component and one selected-tab style for both.
