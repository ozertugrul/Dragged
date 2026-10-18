import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Menu Bar Item
        statusBarController = StatusBarController()

        // Setup Global Shortcut / Shift monitoring
        GlobalEventMonitor.shared.startMonitoring()

        // Setup System Notifications
        NotificationManager.shared.setup()

        // Open Converter Window automatically on start
        statusBarController?.openQuickConverter()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        GlobalEventMonitor.shared.stopMonitoring()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            statusBarController?.openQuickConverter()
        }
        return true
    }
}
