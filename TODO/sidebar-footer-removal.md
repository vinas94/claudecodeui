# Remove the sidebar footer; Settings gear goes to the header

## Wanted

- The sidebar extends all the way to the bottom: remove the footer section entirely.
- Drop Report Issue, Join Community and the version line ("CloudCLI v1.37.3 – Open
  Source").
- Put the Settings gear in the header, next to refresh, + (new) and collapse.

## Where

- Footer: `src/modules/sidebar/SidebarFooter.tsx`, rendered by `SidebarContent.tsx`.
- Header buttons: `src/modules/sidebar/SidebarHeader.tsx`.
- Collapsed sidebar has the same buttons: `src/modules/sidebar/SidebarCollapsed.tsx`
  (keep only Settings there too).

## Update notice: keep it, find a new place

The footer also hosts the "update available" and "restart required" banners
(`SidebarFooter.tsx`). The update notice must stay: removing the footer means finding
another place for it (open question, e.g. a badge on the Settings gear or a small
header indicator).

- It should report a new upstream release (tag) newer than the one `main-patched` is
  based on, and point to `just update`, not to upstream's npm update.
- "Restart required" becomes "quit and reopen CloudCLI" after a `just update`.
