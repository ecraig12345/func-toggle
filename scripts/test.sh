#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
swift test \
    -Xswiftc -F -Xswiftc "$frameworks" \
    -Xlinker "-F$frameworks" \
    -Xlinker -rpath -Xlinker "$frameworks"
