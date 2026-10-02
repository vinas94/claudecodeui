# Fork-local glue: lives on main-patched only. Run from a normal terminal.

app := env("HOME") / "Applications/CloudCLI.app"
config := env("HOME") / ".config/cloudcli/config"
log := env("HOME") / "Library/Logs/cloudcli.log"
port := "3001"  # keep in sync with SERVER_PORT in the config

[private]
default:
    @just --list --unsorted

# Build the server and install ~/Applications/CloudCLI.app (opening it starts the server, quitting stops it)
install: check-config build app

# Rebase main-patched onto upstream's latest release, rebuild, reinstall the app
update: clean-tree
    #!/usr/bin/env bash
    set -euo pipefail
    git fetch upstream --tags
    tag="$(git describe --tags --abbrev=0 upstream/main)"
    git tag -f deployed-prev main-patched
    git switch main
    git merge --ff-only upstream/main
    git push origin main
    git switch main-patched
    git rebase "$tag" || { echo "rebase stopped on a conflict: resolve, git rebase --continue, rerun just update"; exit 1; }
    just build app
    git push --force-with-lease origin main-patched
    echo "built $tag + patches; quit and reopen CloudCLI to run it"

# Go back to the build before the last update
rollback: clean-tree
    git switch --detach deployed-prev
    just build app
    @echo "on deployed-prev (detached); quit and reopen CloudCLI. The next just update returns to main-patched"

# Rebuild main-patched in place, e.g. after a Node major bump
rebuild: clean-tree
    git switch main-patched
    just build app
    @echo "quit and reopen CloudCLI to run it"

logs:
    tail -f "{{log}}"

# Remove the app (keeps ~/.cloudcli data)
uninstall:
    rm -r "{{app}}"

[private]
build:
    npm ci
    npm run build

[private]
app:
    launcher/install-app.sh "{{app}}" "{{config}}" "{{port}}"

[private]
check-config:
    @[ -f "{{config}}" ] || { echo "{{config}} missing: it comes from nix-env (just switch)"; exit 1; }

[private]
clean-tree:
    @[ -z "$(git status --porcelain)" ] || { echo "working tree not clean; commit or stash first"; exit 1; }
