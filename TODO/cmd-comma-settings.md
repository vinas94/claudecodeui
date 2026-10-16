# Cmd+, opens Settings

## Wanted

Cmd+, opens Settings, like any Mac app.

## How

- Web side: settings already open through `openSettings` (used by the command palette,
  `src/modules/project-workspace/ProjectCommandPalette.tsx`). Add a Cmd+, keyboard
  shortcut that calls it, so it also works in a browser tab.
- Launcher: add "Settings… ⌘," to the CloudCLI app menu
  (`launcher/Sources/cloudcli-launcher/main.swift`, `buildMenu`). Without a menu item,
  WebKit may not pass Cmd+, to the page; the item can trigger the web shortcut (or call
  a small hook exposed on `window`).
