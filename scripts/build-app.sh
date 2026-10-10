#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
swift build --configuration release --product FuncToggle
bin_path="$(swift build --configuration release --show-bin-path)"
app_path="$PWD/build/FuncToggle.app"

# SwiftPM generates a command-line resource lookup, not a macOS app lookup.
accessor="$bin_path/KeyboardShortcuts.build/DerivedSources/resource_bundle_accessor.swift"
if grep -q 'Bundle.main.bundleURL.appendingPathComponent' "$accessor"; then
    sed -i '' \
        's/Bundle.main.bundleURL.appendingPathComponent/(Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent/' \
        "$accessor"
elif ! grep -q 'Bundle.main.resourceURL ?? Bundle.main.bundleURL' "$accessor"; then
    printf 'Unexpected SwiftPM resource accessor: %s\n' "$accessor" >&2
    exit 1
fi
swift build --configuration release --product FuncToggle

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/FuncToggle" "$app_path/Contents/MacOS/FuncToggle"
cp Resources/Info.plist "$app_path/Contents/Info.plist"

for bundle in "$bin_path"/*.bundle; do
    if [[ -d "$bundle" ]]; then
        ditto "$bundle" "$app_path/Contents/Resources/$(basename "$bundle")"
    fi
done

plutil -lint "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path"
codesign --verify --strict --verbose=2 "$app_path"
printf '\nBuilt %s\nRun: open "%s"\n' "$app_path" "$app_path"
