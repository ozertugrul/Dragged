import Foundation
import AppKit
import UserNotifications

public class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    public func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    public func notifySuccess(actionTitle: String, destinationURL: URL, sourceSize: Int64, destSize: Int64) {
        let filename = destinationURL.lastPathComponent

        var sizeDiffText = ""
        if sourceSize > 0 && destSize > 0 {
            if destSize < sourceSize {
                let saved = Int(round((1.0 - (Double(destSize) / Double(sourceSize))) * 100.0))
                sizeDiffText = " • Saved \(saved)%"
            } else {
                let srcMB = ByteCountFormatter.string(fromByteCount: sourceSize, countStyle: .file)
                let dstMB = ByteCountFormatter.string(fromByteCount: destSize, countStyle: .file)
                sizeDiffText = " (\(srcMB) → \(dstMB))"
            }
        }

        let body = "\(filename)\(sizeDiffText)"
        sendNotification(title: actionTitle, subtitle: "Saved in Finder", body: body, fileURL: destinationURL)
    }

    public func notifyFailure(actionTitle: String, errorMessage: String) {
        sendNotification(title: "\(actionTitle) Failed", subtitle: nil, body: errorMessage, fileURL: nil)
    }

    public func sendNotification(title: String, subtitle: String? = nil, body: String, fileURL: URL? = nil) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        if let s = subtitle {
            content.subtitle = s
        }
        content.body = body
        content.sound = .default

        if let url = fileURL {
            content.userInfo = ["fileURL": url.path]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { error in
            if let err = error {
                NSLog("Failed to schedule notification: \(err.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let path = response.notification.request.content.userInfo["fileURL"] as? String {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        completionHandler()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even if app is foreground
        completionHandler([.banner, .sound])
    }
}
