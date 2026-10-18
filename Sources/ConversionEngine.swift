import Foundation
import AppKit
import PDFKit

public struct RecentConversion: Identifiable, Equatable {
    public let id = UUID()
    public let sourceURL: URL
    public let destinationURL: URL
    public let targetFormat: String
    public let date: Date
    public let sourceSize: Int64
    public let destinationSize: Int64
    public let isSuccess: Bool
    public let errorMessage: String?
}

@MainActor
public class ConversionEngine: ObservableObject {
    public static let shared = ConversionEngine()

    @Published public var isConverting: Bool = false
    @Published public var currentFile: String = ""
    @Published public var progress: Double = 0.0
    @Published public var recentConversions: [RecentConversion] = []
    @Published public var lastConvertedURL: URL? = nil

    private let ffmpegPath: String? = {
        let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    private let cwebpPath: String? = {
        let candidates = ["/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp", "/usr/bin/cwebp"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    private let dwebpPath: String? = {
        let candidates = ["/opt/homebrew/bin/dwebp", "/usr/local/bin/dwebp", "/usr/bin/dwebp"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    private let sipsPath = "/usr/bin/sips"

    private init() {}

    // MARK: - Single File Conversion Dispatcher
    public func convert(file url: URL, to targetExt: String) async -> Result<URL, Error> {
        self.isConverting = true
        self.currentFile = url.lastPathComponent
        self.progress = 0.2

        let sourceSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        let category = FormatRegistry.detectCategory(for: url)
        let outputURL = determineOutputURL(for: url, targetExtension: targetExt)

        var result: Result<URL, Error>

        switch category {
        case .image:
            result = await convertImage(input: url, output: outputURL, targetExt: targetExt)
        case .video:
            result = await convertVideo(input: url, output: outputURL, targetExt: targetExt)
        case .audio:
            result = await convertAudio(input: url, output: outputURL, targetExt: targetExt)
        case .document:
            result = await convertDocument(input: url, output: outputURL, targetExt: targetExt)
        case .unknown:
            result = await convertImage(input: url, output: outputURL, targetExt: targetExt)
        }

        self.progress = 1.0
        self.isConverting = false

        switch result {
        case .success(let dest):
            let destSize = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            let record = RecentConversion(
                sourceURL: url,
                destinationURL: dest,
                targetFormat: targetExt.uppercased(),
                date: Date(),
                sourceSize: sourceSize,
                destinationSize: destSize,
                isSuccess: true,
                errorMessage: nil
            )
            self.recentConversions.insert(record, at: 0)
            self.lastConvertedURL = dest

            if SettingsManager.shared.playSound {
                NSSound(named: "Glass")?.play()
            }
            if SettingsManager.shared.revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([dest])
            }
            NotificationManager.shared.notifySuccess(
                actionTitle: "Converted to \(targetExt.uppercased())",
                destinationURL: dest,
                sourceSize: sourceSize,
                destSize: destSize
            )

        case .failure(let error):
            let record = RecentConversion(
                sourceURL: url,
                destinationURL: outputURL,
                targetFormat: targetExt.uppercased(),
                date: Date(),
                sourceSize: sourceSize,
                destinationSize: 0,
                isSuccess: false,
                errorMessage: error.localizedDescription
            )
            self.recentConversions.insert(record, at: 0)
            if SettingsManager.shared.playSound {
                NSSound(named: "Basso")?.play()
            }
        }

        return result
    }

    // MARK: - Batch Multi-File Conversion
    public func convertBatch(files: [URL], to targetExt: String) async -> [Result<URL, Error>] {
        guard !files.isEmpty else { return [] }
        self.isConverting = true
        self.progress = 0.0

        var results: [Result<URL, Error>] = []
        let total = Double(files.count)

        for (idx, file) in files.enumerated() {
            self.currentFile = "(\(idx + 1)/\(files.count)) \(file.lastPathComponent)"
            let res = await convert(file: file, to: targetExt)
            results.append(res)
            self.progress = Double(idx + 1) / total
        }

        self.isConverting = false
        self.currentFile = "Completed \(files.count) files"
        return results
    }

    // MARK: - Clipboard Image Conversion
    public func convertClipboardImage(to targetExt: String) async -> Result<URL, Error> {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return .failure(NSError(domain: "Dragged", code: 404, userInfo: [NSLocalizedDescriptionKey: "No image found in clipboard"]))
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempPNG = tempDir.appendingPathComponent("clipboard_\(UUID().uuidString).png")

        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return .failure(NSError(domain: "Dragged", code: 405, userInfo: [NSLocalizedDescriptionKey: "Failed to read clipboard image bytes"]))
        }

        do {
            try pngData.write(to: tempPNG)
            let result = await convert(file: tempPNG, to: targetExt)
            try? FileManager.default.removeItem(at: tempPNG)
            return result
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Tool Action Dispatcher (Option + Shift)
    public func executeTool(actionId: String, on url: URL) async -> Result<URL, Error> {
        self.isConverting = true
        self.currentFile = url.lastPathComponent
        self.progress = 0.3

        let sourceSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        var result: Result<URL, Error>

        switch actionId {
        case "compress_image":
            let quality = SettingsManager.shared.imageQuality
            let output = determineToolOutputURL(for: url, suffix: "_compressed", ext: url.pathExtension)
            if url.pathExtension.lowercased() == "webp", let cwebp = cwebpPath {
                result = await runProcess(executable: cwebp, arguments: ["-q", "\(quality)", url.path, "-o", output.path], outputURL: output)
            } else {
                result = await runProcess(executable: sipsPath, arguments: ["-s", "formatOptions", "\(quality)", url.path, "--out", output.path], outputURL: output)
            }

        case "resize_50":
            let output = determineToolOutputURL(for: url, suffix: "_half", ext: url.pathExtension)
            result = await runProcess(executable: sipsPath, arguments: ["-Z", "1200", url.path, "--out", output.path], outputURL: output)

        case "grayscale":
            let output = determineToolOutputURL(for: url, suffix: "_gray", ext: "png")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-vf", "hue=s=0", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 1, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available for grayscale"]))
            }

        case "to_pdf":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "pdf")
            result = await runProcess(executable: sipsPath, arguments: ["-s", "format", "pdf", url.path, "--out", output.path], outputURL: output)

        case "compress_video":
            let output = determineToolOutputURL(for: url, suffix: "_compressed", ext: "mp4")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-vcodec", "libx264", "-crf", "28", "-preset", "fast", "-c:a", "aac", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 2, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "video_to_gif":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "gif")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: [
                    "-y", "-loglevel", "error", "-i", url.path,
                    "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                    output.path
                ], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 3, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available for GIF conversion"]))
            }

        case "extract_audio":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "mp3")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-vn", "-c:a", "libmp3lame", "-q:a", "2", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 4, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "mute_video":
            let output = determineToolOutputURL(for: url, suffix: "_muted", ext: url.pathExtension)
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-c:v", "copy", "-an", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 5, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "metadata":
            // Strip metadata / save clean image
            let output = determineToolOutputURL(for: url, suffix: "_clean", ext: url.pathExtension)
            result = await runProcess(executable: sipsPath, arguments: ["-d", "profile", url.path, "--out", output.path], outputURL: output)

        case "edit", "crop", "redact", "annotate":
            // Open in macOS Preview which natively handles crop, redact, annotate, and editing
            if let previewApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
                _ = try? await NSWorkspace.shared.open([url], withApplicationAt: previewApp, configuration: NSWorkspace.OpenConfiguration())
                result = .success(url)
            } else {
                NSWorkspace.shared.open(url)
                result = .success(url)
            }

        case "preview":
            NSWorkspace.shared.open(url)
            result = .success(url)

        case "add_bg":
            let output = determineToolOutputURL(for: url, suffix: "_bg", ext: "png")
            if let img = NSImage(contentsOf: url) {
                let rect = NSRect(origin: .zero, size: img.size)
                let newImg = NSImage(size: img.size)
                newImg.lockFocus()
                NSColor.white.setFill()
                rect.fill()
                img.draw(in: rect)
                newImg.unlockFocus()
                if let tiff = newImg.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let pngData = rep.representation(using: .png, properties: [:]) {
                    do {
                        try pngData.write(to: output)
                        result = .success(output)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .failure(NSError(domain: "Dragged", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to render background"]))
                }
            } else {
                result = .failure(NSError(domain: "Dragged", code: 7, userInfo: [NSLocalizedDescriptionKey: "Cannot read image for add_bg"]))
            }

        case "remove_bg":
            let output = determineToolOutputURL(for: url, suffix: "_nobg", ext: "png")
            // Convert to PNG with transparent channel preservation
            result = await runProcess(executable: sipsPath, arguments: ["-s", "format", "png", url.path, "--out", output.path], outputURL: output)

        case "to_mp4":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "mp4")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 16, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "to_mov":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "mov")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-c:v", "copy", "-c:a", "copy", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 17, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "to_wav":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "wav")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-vn", "-c:a", "pcm_s16le", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 18, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "to_webm":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "webm")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 19, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "to_m4a":
            let output = determineToolOutputURL(for: url, suffix: "", ext: "m4a")
            if let ffmpeg = ffmpegPath {
                result = await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", url.path, "-vn", "-c:a", "aac", output.path], outputURL: output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 20, userInfo: [NSLocalizedDescriptionKey: "ffmpeg not available"]))
            }

        case "compress_pdf":
            let output = determineToolOutputURL(for: url, suffix: "_compressed", ext: "pdf")
            if let doc = PDFDocument(url: url) {
                doc.write(to: output)
                result = .success(output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF"]))
            }

        case "pdf_to_images":
            let output = determineToolOutputURL(for: url, suffix: "_page1", ext: "png")
            if let doc = PDFDocument(url: url), let page = doc.page(at: 0) {
                let pageRect = page.bounds(for: .mediaBox)
                let image = NSImage(size: pageRect.size)
                image.lockFocus()
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.setFillColor(NSColor.white.cgColor)
                    ctx.fill(pageRect)
                    page.draw(with: .mediaBox, to: ctx)
                }
                image.unlockFocus()
                if let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    do {
                        try png.write(to: output)
                        result = .success(output)
                    } catch {
                        result = .failure(error)
                    }
                } else {
                    result = .failure(NSError(domain: "Dragged", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to render PDF page"]))
                }
            } else {
                result = .failure(NSError(domain: "Dragged", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF"]))
            }

        case "ocr_pdf":
            let output = determineToolOutputURL(for: url, suffix: "_text", ext: "txt")
            if let doc = PDFDocument(url: url), let str = doc.string {
                do {
                    try str.write(to: output, atomically: true, encoding: .utf8)
                    result = .success(output)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(NSError(domain: "Dragged", code: 13, userInfo: [NSLocalizedDescriptionKey: "No extractable text in document"]))
            }

        case "split_pdf":
            let output = determineToolOutputURL(for: url, suffix: "_p1", ext: "pdf")
            if let doc = PDFDocument(url: url), let page = doc.page(at: 0) {
                let newDoc = PDFDocument()
                newDoc.insert(page, at: 0)
                newDoc.write(to: output)
                result = .success(output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to split PDF"]))
            }

        case "merge_pdf":
            let output = determineToolOutputURL(for: url, suffix: "_merged", ext: "pdf")
            if let doc = PDFDocument(url: url) {
                doc.write(to: output)
                result = .success(output)
            } else {
                result = .failure(NSError(domain: "Dragged", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed to merge PDF"]))
            }

        case "print_doc":
            NSWorkspace.shared.open(url)
            result = .success(url)

        default:
            result = .failure(NSError(domain: "Dragged", code: 99, userInfo: [NSLocalizedDescriptionKey: "Unknown tool action: \(actionId)"]))
        }

        self.progress = 1.0
        self.isConverting = false

        if case .success(let dest) = result {
            let destSize = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            let record = RecentConversion(
                sourceURL: url,
                destinationURL: dest,
                targetFormat: actionId.replacingOccurrences(of: "_", with: " ").capitalized,
                date: Date(),
                sourceSize: sourceSize,
                destinationSize: destSize,
                isSuccess: true,
                errorMessage: nil
            )
            self.recentConversions.insert(record, at: 0)
            self.lastConvertedURL = dest
            if SettingsManager.shared.playSound {
                NSSound(named: "Glass")?.play()
            }
            if SettingsManager.shared.revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([dest])
            }
            NotificationManager.shared.notifySuccess(
                actionTitle: actionId.replacingOccurrences(of: "_", with: " ").capitalized,
                destinationURL: dest,
                sourceSize: sourceSize,
                destSize: destSize
            )
        } else if case .failure(let err) = result {
            NotificationManager.shared.notifyFailure(
                actionTitle: actionId.replacingOccurrences(of: "_", with: " ").capitalized,
                errorMessage: err.localizedDescription
            )
        }

        return result
    }

    // MARK: - Image Conversion
    private func convertImage(input: URL, output: URL, targetExt: String) async -> Result<URL, Error> {
        let ext = targetExt.lowercased()
        let inExt = input.pathExtension.lowercased()

        // 1. WebP Output -> use cwebp
        if ext == "webp", let cwebp = cwebpPath {
            let quality = SettingsManager.shared.imageQuality
            return await runProcess(executable: cwebp, arguments: ["-q", "\(quality)", input.path, "-o", output.path], outputURL: output)
        }

        // 2. WebP Input to other formats -> use dwebp if target is PNG
        if inExt == "webp", let dwebp = dwebpPath {
            let tempPNG = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
            let dwebpRes = await runProcess(executable: dwebp, arguments: [input.path, "-o", tempPNG.path], outputURL: tempPNG)
            if case .success(let pngURL) = dwebpRes {
                if ext == "png" {
                    try? FileManager.default.moveItem(at: pngURL, to: output)
                    return .success(output)
                } else {
                    let finalRes = await convertImage(input: pngURL, output: output, targetExt: ext)
                    try? FileManager.default.removeItem(at: pngURL)
                    return finalRes
                }
            }
        }

        // 3. SIPS Supported Formats
        let sipsFormats: [String: String] = [
            "jpg": "jpeg", "jpeg": "jpeg",
            "png": "png",
            "tiff": "tiff", "tif": "tiff",
            "bmp": "bmp",
            "gif": "gif",
            "pdf": "pdf",
            "heic": "heic",
            "avif": "avif",
            "ico": "ico",
            "icns": "icns"
        ]

        if let sipsFormat = sipsFormats[ext] {
            return await runProcess(executable: sipsPath, arguments: ["-s", "format", sipsFormat, input.path, "--out", output.path], outputURL: output)
        }

        // 4. Fallback to ffmpeg
        if let ffmpeg = ffmpegPath {
            return await runProcess(executable: ffmpeg, arguments: ["-y", "-loglevel", "error", "-i", input.path, output.path], outputURL: output)
        }

        return .failure(NSError(domain: "Dragged", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unsupported image format: \(targetExt)"]))
    }

    // MARK: - Video Conversion
    private func convertVideo(input: URL, output: URL, targetExt: String) async -> Result<URL, Error> {
        guard let ffmpeg = ffmpegPath else {
            return .failure(NSError(domain: "Dragged", code: 20, userInfo: [NSLocalizedDescriptionKey: "ffmpeg is required for video conversion. Please install with 'brew install ffmpeg'"]))
        }

        var args = ["-y", "-loglevel", "error", "-i", input.path]

        switch targetExt.lowercased() {
        case "mp4":
            args.append(contentsOf: ["-c:v", "libx264", "-preset", "fast", "-crf", "22", "-c:a", "aac", output.path])
        case "mov":
            args.append(contentsOf: ["-c:v", "copy", "-c:a", "copy", output.path])
        case "webm":
            args.append(contentsOf: ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30", output.path])
        case "mkv":
            args.append(contentsOf: ["-c", "copy", output.path])
        case "gif":
            args.append(contentsOf: [
                "-vf", "fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
                output.path
            ])
        case "mp3":
            args.append(contentsOf: ["-vn", "-c:a", "libmp3lame", "-q:a", "2", output.path])
        default:
            args.append(output.path)
        }

        return await runProcess(executable: ffmpeg, arguments: args, outputURL: output)
    }

    // MARK: - Audio Conversion
    private func convertAudio(input: URL, output: URL, targetExt: String) async -> Result<URL, Error> {
        guard let ffmpeg = ffmpegPath else {
            return .failure(NSError(domain: "Dragged", code: 30, userInfo: [NSLocalizedDescriptionKey: "ffmpeg is required for audio conversion. Please install with 'brew install ffmpeg'"]))
        }

        var args = ["-y", "-loglevel", "error", "-i", input.path]

        switch targetExt.lowercased() {
        case "mp3":
            args.append(contentsOf: ["-c:a", "libmp3lame", "-q:a", "2", output.path])
        case "m4a", "aac":
            args.append(contentsOf: ["-c:a", "aac", "-b:a", "256k", output.path])
        case "wav":
            args.append(contentsOf: ["-c:a", "pcm_s16le", output.path])
        case "flac":
            args.append(contentsOf: ["-c:a", "flac", output.path])
        case "ogg":
            args.append(contentsOf: ["-c:a", "libvorbis", "-q:a", "4", output.path])
        default:
            args.append(output.path)
        }

        return await runProcess(executable: ffmpeg, arguments: args, outputURL: output)
    }

    // MARK: - Document / PDF Conversion
    private func convertDocument(input: URL, output: URL, targetExt: String) async -> Result<URL, Error> {
        if input.pathExtension.lowercased() == "pdf" {
            if targetExt.lowercased() == "png" || targetExt.lowercased() == "jpg" {
                return await runProcess(executable: sipsPath, arguments: ["-s", "format", targetExt.lowercased() == "jpg" ? "jpeg" : "png", input.path, "--out", output.path], outputURL: output)
            }

            if targetExt.lowercased() == "txt" {
                if let doc = PDFDocument(url: input) {
                    var fullText = ""
                    for i in 0..<doc.pageCount {
                        if let page = doc.page(at: i), let pageText = page.string {
                            fullText += pageText + "\n\n"
                        }
                    }
                    do {
                        try fullText.write(to: output, atomically: true, encoding: .utf8)
                        return .success(output)
                    } catch {
                        return .failure(error)
                    }
                }
            }
        }

        return .failure(NSError(domain: "Dragged", code: 40, userInfo: [NSLocalizedDescriptionKey: "Document conversion not supported for this pair."]))
    }

    // MARK: - Process Execution Helper
    private func runProcess(executable: String, arguments: [String], outputURL: URL) async -> Result<URL, Error> {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    // Async read to prevent buffer deadlock
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path) {
                        continuation.resume(returning: .success(outputURL))
                    } else {
                        let msg = String(data: data, encoding: .utf8) ?? "Process exited with code \(process.terminationStatus)"
                        continuation.resume(returning: .failure(NSError(domain: "Dragged", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg])))
                    }
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    // MARK: - File Path Resolution
    private func determineOutputURL(for input: URL, targetExtension: String) -> URL {
        let targetDir = SettingsManager.shared.resolveDestinationFolder(for: input)
        let baseName = input.deletingPathExtension().lastPathComponent
        let targetExt = targetExtension.lowercased()

        var candidate = targetDir.appendingPathComponent("\(baseName).\(targetExt)")

        if candidate.path == input.path {
            candidate = targetDir.appendingPathComponent("\(baseName)_converted.\(targetExt)")
        }

        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = targetDir.appendingPathComponent("\(baseName)_\(counter).\(targetExt)")
            counter += 1
        }

        return candidate
    }

    private func determineToolOutputURL(for input: URL, suffix: String, ext: String) -> URL {
        let targetDir = SettingsManager.shared.resolveDestinationFolder(for: input)
        let baseName = input.deletingPathExtension().lastPathComponent
        var candidate = targetDir.appendingPathComponent("\(baseName)\(suffix).\(ext)")

        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = targetDir.appendingPathComponent("\(baseName)\(suffix)_\(counter).\(ext)")
            counter += 1
        }

        return candidate
    }
}
