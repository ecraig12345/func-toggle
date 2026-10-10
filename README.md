# FuncToggle

A small native macOS menu-bar app (`func-toggle`) that switches between standard F1-F12 keys and media/brightness keys using a configurable global shortcut. Built with Swift Package Manager; no Xcode project or IDE required.

Due to Apple's developer requirements for signing apps, currently you'll need to download the code and build your own copy locally (no Apple Developer account is required).

## Requirements

- macOS 15 or later, with a keyboard that supports Apple's function-key mode setting.
- Swift 6.4.0, managed by [Swiftly](https://www.swift.org/install/macos/) and pinned in `.swift-version`.
- Apple Command Line Tools for the macOS SDK, signing, and bundling utilities.

## Set up the toolchain

Install Apple's tools if needed:

```bash
xcode-select --install
```

Install Swiftly using the official installer (skip this step if Swiftly is already installed):

```bash
curl --fail --location --output swiftly.pkg https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
rm swiftly.pkg
~/.swiftly/bin/swiftly init --skip-install --quiet-shell-followup
```

Open a new terminal, navigate to the root of the git clone of this repo, and run:

```bash
swiftly install 6.4.0
swiftly run swift --version
swiftly run swift package --version
```

## Build and run

The build script activates Swiftly and uses `swiftly run` to honor the project version. It creates a complete app bundle, includes dependency resources, and ad-hoc signs it for local use (this copy is not a Developer ID signed or notarized distribution build).

Quit any previously-running copy of the app, then run:

```bash
bash scripts/build-app.sh
open build/FuncToggle.app
```

Optionally, you can copy the app to your Applications folder after building.

## Using the app

Settings open on first launch. The default global shortcut is `Command-Option-Tab`. Click the shortcut recorder to change it (the recorder only captures keys after you click it), or use its clear button to disable it. The shortcut is saved automatically and works while other apps are active.

The menu bar icon indicates the app's current state: F for standard F1-F12, a sun icon for media keys, or `fn: ?` when macOS cannot report the mode. Its menu provides options to toggle the mode, open settings, or quit the app.

To install locally, copy `build/FuncToggle.app` into `~/Applications` (create that folder if necessary). Quit an installed copy before replacing it manually. You can add it under System Settings > General > Login Items if you want it to launch at login.

## How it works and limitations

FuncToggle reads `HIDFKeyMode` from `IOHIDSystem` and changes it with `IOHIDSetCFTypeParameter`. It verifies the reported mode after each change and displays an alert on failure. This is a low-level mechanism, not a guaranteed high-level macOS API; actual key behavior must be tested on your macOS version and keyboard. Third-party keyboards with their own Fn-lock may not follow this setting.

The app changes the live keyboard mode; it does not rewrite the stored System Settings preference, promise persistence across restart, restore the previous mode when quitting, or remap individual keys.

The app is not sandboxed. It does not use GUI scripting, an event-tap keyboard monitor, privileged helper, or accessibility prompt. If macOS refuses keyboard-service access, the error is surfaced.

## Validation

The test script activates Swiftly and uses `swiftly run` to honor the project version.

```bash
bash scripts/test.sh
build/FuncToggle.app/Contents/MacOS/FuncToggle --check
```

`--check` prints the current mode and exits without changing it or opening the UI. Tests cover mode values, reversible toggling, and error descriptions; they never alter your keyboard settings.

The [GitHub Actions workflow](.github/workflows/validate.yml) runs on pushes, pull requests, and manual dispatch using a macOS 15 runner. It installs the pinned toolchain through Swiftly, checks shell syntax, runs tests, and builds the app with ad-hoc signature verification. It does not upload artifacts or require signing credentials. Hardware mode detection (`--check`), global shortcut interaction, and physical key behavior are not tested in CI.

For an end-to-end test, choose a shortcut, focus another application, and press the shortcut. Confirm the indicator changes and a physical function key changes behavior immediately, then press the shortcut again to restore the previous mode. Quit and relaunch to verify the shortcut was saved.

## References

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) supplies the global shortcut and recorder. Version 1.14.0 is pinned because it uses `PreviewProvider` rather than requiring Xcode-only SwiftUI compiler plugins.
- [Fluor's FKeyManager](https://github.com/Pyroh/Fluor/blob/master/Fluor/Misc/FKeyManager.swift) demonstrates the IOKit mechanism. FuncToggle's implementation is written independently, with only the core feature of a global keyboard shortcut-based toggle and a menu bar icon for state (no per-app modes or other features).
