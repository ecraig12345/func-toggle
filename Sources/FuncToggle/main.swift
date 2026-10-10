import AppKit
import FunctionKeys
import KeyboardShortcuts
import OSLog

@MainActor
extension KeyboardShortcuts.Name {
    static let toggleFunctionKeys = Self(
        "toggleFunctionKeys",
        default: .init(.tab, modifiers: [.command, .option])
    )
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "local.FnToggle", category: "Keyboard")
    private var statusItem: NSStatusItem?
    private var modeItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        let modeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(modeItem)
        self.modeItem = modeItem
        menu.addItem(.separator())
        addItem("Toggle function keys", action: #selector(toggleMode), to: menu)
        addItem("Settings...", action: #selector(showSettings), to: menu)
        menu.addItem(.separator())
        addItem("Quit FuncToggle", action: #selector(quit), to: menu)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = menu
        statusItem = item
        refreshMode()

        KeyboardShortcuts.onKeyUp(for: .toggleFunctionKeys) { [weak self] in
            self?.toggleMode()
        }

        if !UserDefaults.standard.bool(forKey: "hasShownSettings") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasShownSettings")
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
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
        statusItem?.button?.title = mode.indicator
        statusItem?.button?.toolTip = "FuncToggle: \(mode.title)"
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
        statusItem?.button?.title = "fn: ?"
        statusItem?.button?.toolTip = error.localizedDescription
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
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "FuncToggle settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()

            let title = NSTextField(labelWithString: "Global shortcut")
            title.font = .boldSystemFont(ofSize: 14)
            let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleFunctionKeys)
            let explanation = NSTextField(wrappingLabelWithString:
                "Click the recorder and press a shortcut. It works while other apps are active. Clear it with the recorder's clear button.\n\nSwitches between standard F1-F12 and media/brightness keys. Hold Fn to use the opposite behavior."
            )
            explanation.textColor = .secondaryLabelColor
            let done = NSButton(title: "Done", target: self, action: #selector(closeSettings))
            window.initialFirstResponder = done

            let stack = NSStackView(views: [title, recorder, explanation, done])
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
                    stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
                ])
            }
            settingsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        if let lastError {
            showError(lastError)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        settingsWindow?.makeFirstResponder(nil)
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow?.makeFirstResponder(nil)
    }

    @objc private func closeSettings() {
        settingsWindow?.close()
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
