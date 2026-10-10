#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
source "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"
swiftly run swift test
