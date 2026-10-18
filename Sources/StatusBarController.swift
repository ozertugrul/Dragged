import AppKit
import SwiftUI

@MainActor
public class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var quickWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    public override init() {
        super.init()
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = ""
            if let image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "Dragged") {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "Dragged: Instant Gesture File Converter"
            button.target = self
            button.action = #selector(statusBarClicked)
        }

        buildMenu()
    }

    public func buildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Dragged (v1.0.0)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let openWindowItem = NSMenuItem(title: "Open Converter Window...", action: #selector(openQuickConverter), keyEquivalent: "o")
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        let radialItem = NSMenuItem(title: "Trigger Radial Wheel at Cursor", action: #selector(showRadialWheel), keyEquivalent: "r")
        radialItem.target = self
        menu.addItem(radialItem)

        menu.addItem(NSMenuItem.separator())

        // Clipboard Converter Submenu
        let clipMenu = NSMenu()
        let clipFormats = ["WebP", "PNG", "JPEG", "PDF"]
        for fmt in clipFormats {
            let item = NSMenuItem(title: "Convert Clipboard to \(fmt)", action: #selector(convertClipboard(_:)), keyEquivalent: "")
            item.representedObject = fmt.lowercased()
            item.target = self
            clipMenu.addItem(item)
        }
        let clipItem = NSMenuItem(title: "Clipboard Image Converter", action: nil, keyEquivalent: "")
        clipItem.submenu = clipMenu
        menu.addItem(clipItem)

        // Quick File Conversion Submenu
        let testSubmenu = NSMenu()
        let formats = ["WebP", "PNG", "JPEG", "MP4", "GIF", "MP3", "PDF"]
        for fmt in formats {
            let item = NSMenuItem(title: "Convert File to \(fmt)...", action: #selector(chooseFileToConvert(_:)), keyEquivalent: "")
            item.representedObject = fmt.lowercased()
            item.target = self
            testSubmenu.addItem(item)
        }
        let testItem = NSMenuItem(title: "Convert File from Disk...", action: nil, keyEquivalent: "")
        testItem.submenu = testSubmenu
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        let prefItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefItem.target = self
        menu.addItem(prefItem)

        let aboutItem = NSMenuItem(title: "About Dragged", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit Dragged", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func statusBarClicked() {
        statusItem?.button?.performClick(nil)
    }

    @objc public func openQuickConverter() {
        if let window = quickWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dragged — File Converter"
        window.center()
        window.contentView = NSHostingView(rootView: QuickConverterView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.quickWindow = window
    }

    @objc public func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dragged Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.preferencesWindow = window
    }

    @objc private func showRadialWheel() {
        RadialWindow.shared.showAtCursor(with: nil, toolMode: false)
    }

    @objc private func convertClipboard(_ sender: NSMenuItem) {
        guard let targetExt = sender.representedObject as? String else { return }
        Task {
            let result = await ConversionEngine.shared.convertClipboardImage(to: targetExt)
            switch result {
            case .success(let dest):
                if SettingsManager.shared.revealInFinder {
                    NSWorkspace.shared.activateFileViewerSelecting([dest])
                }
            case .failure(let err):
                let alert = NSAlert()
                alert.messageText = "Clipboard Conversion Failed"
                alert.informativeText = err.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc private func chooseFileToConvert(_ sender: NSMenuItem) {
        guard let targetExt = sender.representedObject as? String else { return }

        let openPanel = NSOpenPanel()
        openPanel.title = "Select File to Convert to \(targetExt.uppercased())"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true

        if openPanel.runModal() == .OK {
            let urls = openPanel.urls
            if urls.count == 1, let single = urls.first {
                Task {
                    _ = await ConversionEngine.shared.convert(file: single, to: targetExt)
                }
            } else if urls.count > 1 {
                Task {
                    _ = await ConversionEngine.shared.convertBatch(files: urls, to: targetExt)
                }
            }
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Dragged for macOS"
        alert.informativeText = """
        Dragged is an advanced gesture-based local file converter built with Swift, AppKit, and SwiftUI.

        Key Features:
        • Shift + Drag to open the circular Radial Wheel directly under your cursor.
        • Scroll wheel or trackpad swipe to cycle between Image Formats, Tools, Media, and PDF/Documents.
        • Option key to toggle between Formats and Tools.
        • 100% offline, private, and local (zero cloud upload).
        • Batch processing: drag multiple files to convert them simultaneously!
        • Clipboard image conversion directly from the menu bar.
        • 100% offline and local (zero cloud upload).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
