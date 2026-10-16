# Shell tab opens Claude Code instead of a shell; tab tooltips repeat the labels

## 1. Shell tab should be a plain shell

Clicking Shell starts the Claude Code CLI (resuming the selected session) in the
terminal instead of a normal shell in the project folder.

Cause: `src/modules/project-workspace/WorkspaceMain.tsx` (around line 175) renders
`<StandaloneShell>` with no `command` and no `isPlainShell`.
`src/modules/standalone-shell/StandaloneShell.tsx` (line 45) treats "no command" as
"not a plain shell", so `Shell.tsx` starts the provider CLI.

Fix: pass `isPlainShell={true}` for the Shell tab. Check that the "Bypass / Disconnect /
Restart" header buttons still make sense for a plain shell.

## 2. Remove tooltips from the Chat / Shell / Files / Source Control tabs

The hover tooltips only repeat the visible label.

Where: `src/modules/project-workspace/WorkspaceTabs.tsx` (line 117, `<Tooltip
content={displayLabel}>`). Drop the tooltip when the label is visible; keep it only if
the tab is ever shown icon-only (e.g. narrow widths).
