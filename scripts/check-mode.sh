#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
app_path="$PWD/build/FuncToggle.app"

if [[ ! -x "$app_path/Contents/MacOS/FuncToggle" ]]; then
	printf 'Build the app first: bash scripts/build-app.sh\n' >&2
	exit 1
fi

exec "$app_path/Contents/MacOS/FuncToggle" --check
