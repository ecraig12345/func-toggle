import AppKit
import FunctionKeys
import KeyboardShortcuts
import OSLog
import ServiceManagement

@MainActor
final class SettingsWindow: NSWindow {
    // Allow Escape to close the settings window.
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}

@MainActor
extension KeyboardShortcuts.Name {
    static let toggleFunctionKeys = Self(
        "toggleFunctionKeys",
        default: .init(.tab, modifiers: [.command, .option])
    )
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "local.FuncToggle", category: "Keyboard")
    private var statusItem: NSStatusItem?
    private var modeItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var openAtLoginButton: NSButton?
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        let modeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(modeItem)
        self.modeItem = modeItem
        menu.addItem(.separator())
        addItem("Toggle mode", action: #selector(toggleMode), to: menu)
        addItem("Settings...", action: #selector(showSettings), to: menu)
        menu.addItem(.separator())
        addItem("Quit FuncToggle", action: #selector(quit), to: menu)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = menu
        // Preserve symbol aspect ratios; stretching can make the sun look oval.
        item.button?.imageScaling = .scaleProportionallyDown
        statusItem = item
        refreshMode()

        KeyboardShortcuts.onKeyUp(for: .toggleFunctionKeys) { [weak self] in
            self?.toggleMode()
        }

        // Show settings on CLI option or first launch.
        if CommandLine.arguments.contains("--show-settings")
            || !UserDefaults.standard.bool(forKey: "hasShownSettings") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasShownSettings")
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Reflect mode changes made outside the app when the user opens the menu.
        refreshMode()
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func updateMode(_ mode: FunctionKeyMode) {
        lastError = nil
        modeItem?.title = "Current mode: \(mode.title)"
        let description = "FuncToggle: \(mode.title)"
        let button = statusItem?.button
        // Configure the glyph, not square image bounds. Menu bar height still limits its visible size.
        let pointSize: CGFloat = mode == .standard ? 18 : 16
        if let image = NSImage(
            systemSymbolName: mode.symbolName,
            accessibilityDescription: description
        )?.withSymbolConfiguration(.init(pointSize: pointSize, weight: .regular)) {
            // Template rendering adapts the icon to the menu bar's light or dark appearance.
            image.isTemplate = true
            button?.image = image
            button?.title = ""
        } else {
            // Keep the current mode visible even if macOS cannot load the symbol.
            logger.error("Status symbol unavailable: \(mode.symbolName, privacy: .public)")
            button?.image = nil
            button?.title = mode.indicator
        }
        // Describe the mode without relying on the user recognizing the symbol.
        button?.toolTip = description
        button?.setAccessibilityLabel(description)
    }

    private func refreshMode() {
        do {
            updateMode(try FunctionKeys.currentMode())
        } catch {
            recordError(error)
        }
    }

    private func recordError(_ error: Error) {
        lastError = error.localizedDescription
        logger.error("\(error.localizedDescription, privacy: .public)")
        modeItem?.title = "Function-key mode unavailable"
        statusItem?.button?.image = nil
        statusItem?.button?.title = "fn: ?"
        statusItem?.button?.toolTip = error.localizedDescription
        statusItem?.button?.setAccessibilityLabel("FuncToggle: \(error.localizedDescription)")
    }

    @objc private func toggleMode() {
        do {
            updateMode(try FunctionKeys.toggle())
        } catch {
            recordError(error)
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not switch function keys"
        alert.informativeText = message
            + "\n\nThis app uses macOS's low-level keyboard service. Support depends on your macOS version and keyboard."
        alert.runModal()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 1),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "FuncToggle settings"
            window.isReleasedWhenClosed = false
            window.delegate = self

            let title = NSTextField(labelWithString: "Global shortcut:")
            let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleFunctionKeys)
            let shortcutRow = NSStackView(views: [title, recorder])
            shortcutRow.orientation = .horizontal
            shortcutRow.alignment = .centerY
            shortcutRow.spacing = 12
            let explanation = NSTextField(wrappingLabelWithString:
                "Click the recorder and press a shortcut. It works while other apps are active. Clear it with the recorder's clear button.\n\nSwitches between standard F1-F12 and media/brightness keys. Hold Fn to use the opposite behavior."
            )
            explanation.textColor = .secondaryLabelColor
            let openAtLogin = NSButton(
                checkboxWithTitle: "Open at login",
                target: self,
                action: #selector(toggleOpenAtLogin)
            )
            openAtLoginButton = openAtLogin

            let stack = NSStackView(views: [shortcutRow, explanation, openAtLogin])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            if let content = window.contentView {
                content.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                    stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                    stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
                    explanation.widthAnchor.constraint(equalTo: stack.widthAnchor)
                ])
                content.layoutSubtreeIfNeeded()
                window.setContentSize(NSSize(
                    width: content.bounds.width,
                    height: stack.fittingSize.height + 48
                ))
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24).isActive = true
            }
            window.center()
            settingsWindow = window
        }
        refreshOpenAtLogin()
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(nil)
        if let lastError {
            showError(lastError)
        }
    }

    private func refreshOpenAtLogin() {
        let status = SMAppService.mainApp.status
        openAtLoginButton?.state = status == .enabled || status == .requiresApproval ? .on : .off
    }

    @objc private func toggleOpenAtLogin() {
        do {
            if openAtLoginButton?.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            refreshOpenAtLogin()
            logger.error("Login item: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not change open at login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return
        }
        refreshOpenAtLogin()
        if SMAppService.mainApp.status == .requiresApproval {
            let alert = NSAlert()
            alert.messageText = "Login item approval required"
            alert.informativeText = "Allow FuncToggle in System Settings > General > Login Items & Extensions to open it at login."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Not now")
            if alert.runModal() == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refreshOpenAtLogin()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Ending recorder editing resumes global shortcuts when switching to another app.
        settingsWindow?.makeFirstResponder(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing Settings must also end recording and resume shortcuts.
        settingsWindow?.makeFirstResponder(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

if CommandLine.arguments.contains("--check") {
    do {
        let mode = try FunctionKeys.currentMode()
        print("Current function-key mode: \(mode.title) (\(mode.rawValue))")
    } catch {
        FileHandle.standardError.write(Data("FuncToggle: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
