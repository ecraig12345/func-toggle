# FuncToggle

A small native macOS menu-bar app (`func-toggle`) that switches between standard F1-F12 keys and media/brightness keys using a configurable global shortcut. Built with Swift Package Manager; no Xcode project or IDE required.

## Requirements

- macOS 15 or later, with a keyboard that supports Apple's function-key mode setting.
- Swift 6.4.0, managed by [Swiftly](https://www.swift.org/install/macos/) and pinned in `.swift-version`.
- Apple Command Line Tools for the macOS SDK, signing, and bundling utilities.
- Internet access for installing the toolchain and the initial fetch of the KeyboardShortcuts dependency.

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

In a new terminal in your project folder:

```bash
swiftly install 6.4.0
swiftly run swift --version
swiftly run swift package --version
```

## Build and run

The build script activates Swiftly and uses `swiftly run` to honor the project version.

```bash
bash scripts/build-app.sh
open build/FuncToggle.app
```

The build script creates a complete app bundle, includes dependency resources, and ad-hoc signs it for local use. No Apple developer account is required. This is not a Developer ID signed or notarized distribution build.

SwiftPM generates resource accessors for command-line executables. The script adjusts the generated KeyboardShortcuts accessor (inside `.build`, not dependency source) to use the app's `Contents/Resources` directory and rebuilds before signing.

Settings open on first launch. The default global shortcut is Command-Option-Tab. Click the shortcut recorder to change it, or use its clear button to disable it. The shortcut is saved automatically and works while other apps are active.

The recorder only captures keys after you click it. Global shortcut handling pauses during recording and resumes when you finish, switch away from Settings, or close the window. Use Done to dismiss Settings without changing your shortcut.

The menu bar shows the `f.square.fill` SF Symbol for standard F1-F12, the `sun.max` SF Symbol for media keys, or `fn: ?` when macOS cannot report the mode. The F symbol uses an 18-point configuration and the sun uses 16 points. Icons adapt to the menu bar appearance, and the tooltip and accessibility label describe the current mode. If a symbol is unavailable, the app logs the issue and uses a text indicator. Its menu provides Toggle function keys, Settings, and Quit. The mode is read again when the menu opens, so external changes are reflected there.

Sizes use native SF Symbol point-size configurations, not resized square image bounds. The status button scales images proportionally to preserve their aspect ratios. macOS still fits the images to the available menu bar height, so the configured point size is not a guarantee of the visible icon height.

Quit any running copy before rebuilding. To install locally, copy `build/FuncToggle.app` into `~/Applications` (create that folder if necessary). You can add it manually under System Settings > General > Login Items if you want it to launch at login.

FuncToggle keeps the original `local.FnToggle` bundle identifier so the rename preserves your saved shortcut and first-launch preferences.

## How it works and limitations

FuncToggle reads `HIDFKeyMode` from `IOHIDSystem` and changes it with `IOHIDSetCFTypeParameter`. It verifies the reported mode after each change and displays an alert on failure. This is a low-level mechanism, not a guaranteed high-level macOS API; actual key behavior must be tested on your macOS version and keyboard. Third-party keyboards with their own Fn-lock may not follow this setting.

The app changes the live keyboard mode; it does not rewrite the stored System Settings preference, promise persistence across restart, or restore the previous mode when quitting. It does not remap individual keys or implement per-app rules.

The app is not sandboxed. It does not use GUI scripting, an event-tap keyboard monitor, or a privileged helper. No Accessibility prompt is added just for shortcut registration. If macOS refuses keyboard-service access, the error is surfaced rather than falling back to clicking System Settings.

## Validation

The test script activates Swiftly and uses `swiftly run` to honor the project version.

```bash
bash scripts/test.sh
build/FuncToggle.app/Contents/MacOS/FuncToggle --check
```

`--check` prints the current mode and exits without changing it or opening the UI. Tests cover mode values, reversible toggling, and error descriptions; they never alter your keyboard settings.

For an end-to-end test, choose a shortcut, focus another application, and press the shortcut. Confirm the indicator changes and a physical function key changes behavior immediately, then press the shortcut again to restore the previous mode. Quit and relaunch to verify the shortcut was saved.

## References

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) supplies the global shortcut and recorder. Version 1.14.0 is pinned because it uses `PreviewProvider` rather than requiring Xcode-only SwiftUI compiler plugins.
- [Fluor's FKeyManager](https://github.com/Pyroh/Fluor/blob/master/Fluor/Misc/FKeyManager.swift) demonstrates the IOKit mechanism. FuncToggle's implementation is written independently.
