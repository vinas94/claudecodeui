# Esc must NOT leave full screen

## Problem

In CloudCLI.app, pressing Esc while the window is in macOS full screen (green button /
Ctrl+Cmd+F) leaves full screen. Esc is used constantly inside the app (closing menus,
dialogs, stopping a turn), so it keeps kicking the window out of full screen.

## Likely cause (not verified)

When the web page doesn't consume Esc, AppKit passes it up the responder chain as
`cancelOperation(_:)`, and a full-screen `NSWindow` handles that by exiting full screen.

## Fix

Launcher (`launcher/Sources/cloudcli-launcher/main.swift`): use an `NSWindow` subclass
that overrides `cancelOperation(_:)` to do nothing, so only Ctrl+Cmd+F / the green button
/ the menu leave full screen. Esc still reaches the page first, so CloudCLI's own Esc
uses (e.g. stopping a running turn, `handleGlobalEscape` in `ChatInterface.tsx`) keep
working.
