import Foundation
import AppKit

public enum SaveDestinationMode: String, CaseIterable, Identifiable {
    case sameAsSource = "Same folder as original file"
    case customFolder = "Dedicated conversion folder"

    public var id: String { rawValue }
}

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    @Published public var destinationMode: SaveDestinationMode {
        didSet { defaults.set(destinationMode.rawValue, forKey: "destinationMode") }
    }

    @Published public var customFolderPath: String {
        didSet { defaults.set(customFolderPath, forKey: "customFolderPath") }
    }

    @Published public var imageQuality: Int {
        didSet { defaults.set(imageQuality, forKey: "imageQuality") }
    }

    @Published public var playSound: Bool {
        didSet { defaults.set(playSound, forKey: "playSound") }
    }

    @Published public var revealInFinder: Bool {
        didSet { defaults.set(revealInFinder, forKey: "revealInFinder") }
    }

    private init() {
        let savedMode = defaults.string(forKey: "destinationMode") ?? SaveDestinationMode.sameAsSource.rawValue
        self.destinationMode = SaveDestinationMode(rawValue: savedMode) ?? .sameAsSource

        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent("Converted").path ?? "~/Downloads/Converted"
        self.customFolderPath = defaults.string(forKey: "customFolderPath") ?? defaultFolder

        let quality = defaults.integer(forKey: "imageQuality")
        self.imageQuality = quality > 0 ? quality : 80

        self.playSound = defaults.object(forKey: "playSound") != nil ? defaults.bool(forKey: "playSound") : true
        self.revealInFinder = defaults.object(forKey: "revealInFinder") != nil ? defaults.bool(forKey: "revealInFinder") : true
    }

    public func resolveDestinationFolder(for sourceFile: URL) -> URL {
        if destinationMode == .customFolder {
            let customURL = URL(fileURLWithPath: customFolderPath)
            if !FileManager.default.fileExists(atPath: customURL.path) {
                try? FileManager.default.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        } else {
            return sourceFile.deletingLastPathComponent()
        }
    }
}
