#!/bin/bash
set -euo pipefail

# Run from the project root so Swiftly honors its .swift-version pin.
cd "$(dirname "$0")/.."
source "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"
swiftly run swift build --configuration release --product FuncToggle
# Ask SwiftPM for the output directory rather than depending on its build layout.
bin_path="$(swiftly run swift build --configuration release --show-bin-path)"
app_path="$PWD/build/FuncToggle.app"

# SwiftPM builds an executable; assemble the macOS app bundle around it.
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/FuncToggle" "$app_path/Contents/MacOS/FuncToggle"
cp Resources/Info.plist "$app_path/Contents/Info.plist"

icon_source="$PWD/Resources/AppIcon/AppIcon.png"
iconset_path="$PWD/build/AppIcon.iconset"
mkdir -p "$iconset_path"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_source" \
        --out "$iconset_path/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$icon_source" \
        --out "$iconset_path/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_path" -o "$app_path/Contents/Resources/AppIcon.icns"

# Swift Build's resource accessor finds dependency bundles in Contents/Resources.
# Unlike the older SwiftPM build engine, it needs no generated-accessor patch or second build.
# ditto preserves their directory structure, including localized resources.
for bundle in "$bin_path"/*.bundle; do
    if [[ -d "$bundle" ]]; then
        ditto "$bundle" "$app_path/Contents/Resources/$(basename "$bundle")"
    fi
done

plutil -lint "$app_path/Contents/Info.plist"
# Ad-hoc signing is sufficient for local use, not notarized distribution.
# Sign only after all bundle contents are in place, then verify the signature.
codesign --force --sign - "$app_path"
codesign --verify --strict --verbose=2 "$app_path"
echo "Built $app_path"
echo "To run: open \"$app_path\""
echo "To install: ./scripts/install-app.sh"
