#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
app_path="$PWD/build/FuncToggle.app"
applications_path="/Applications"
if [[ $# -eq 1 && "$1" == --user ]]; then
    applications_path="$HOME/Applications"
    mkdir -p "$applications_path"
elif [[ $# -ne 0 ]]; then
    printf 'Usage: %s [--user]\n' "$0" >&2
    exit 2
fi
installed_path="$applications_path/FuncToggle.app"

if [[ ! -x "$app_path/Contents/MacOS/FuncToggle" ]]; then
    printf 'Build the app first: bash scripts/build-app.sh\n' >&2
    exit 1
fi

if pgrep -u "$(id -u)" -x FuncToggle >/dev/null; then
    printf 'Quitting FuncToggle...\n'
    osascript <<'APPLESCRIPT'
tell application id "local.FuncToggle" to quit
repeat 100 times
    if not (application id "local.FuncToggle" is running) then return
    delay 0.1
end repeat
error "FuncToggle did not quit within 10 seconds. Installation cancelled."
APPLESCRIPT
    if pgrep -u "$(id -u)" -x FuncToggle >/dev/null; then
        printf 'FuncToggle is still running. Installation cancelled.\n' >&2
        exit 1
    fi
fi

if [[ -e "$installed_path" || -L "$installed_path" ]]; then
    if ! rm -rf "$installed_path"; then
        printf 'Removing the existing app requires administrator authorization.\n' >&2
        sudo rm -rf "$installed_path"
    fi
fi

if ! ditto "$app_path" "$installed_path"; then
    printf 'Copying the app requires administrator authorization.\n' >&2
    sudo ditto "$app_path" "$installed_path"
fi

printf 'Installed %s\n' "$installed_path"
open "$installed_path"