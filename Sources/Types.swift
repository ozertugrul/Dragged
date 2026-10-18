import Foundation
import UniformTypeIdentifiers

// MARK: - File Category
public enum FileCategory: String, CaseIterable, Identifiable {
    case image = "Images"
    case video = "Videos"
    case audio = "Audio"
    case document = "Documents"
    case unknown = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "waveform"
        case .document: return "doc.fill"
        case .unknown: return "doc.questionmark"
        }
    }
}

// MARK: - Target Conversion Format
public struct FormatOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let ext: String
    public let icon: String
    public let category: FileCategory
    public let description: String

    public init(name: String, ext: String, icon: String, category: FileCategory, description: String) {
        self.id = ext.lowercased()
        self.name = name
        self.ext = ext.lowercased()
        self.icon = icon
        self.category = category
        self.description = description
    }
}

// MARK: - Utility Action
public struct ToolOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let icon: String
    public let description: String

    public init(id: String, name: String, icon: String, description: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
    }
}

// MARK: - Format Registry
public enum FormatRegistry {
    // Images
    public static let imageFormats: [FormatOption] = [
        FormatOption(name: "WebP", ext: "webp", icon: "bolt.fill", category: .image, description: "Modern lightweight web image"),
        FormatOption(name: "PNG", ext: "png", icon: "sparkles", category: .image, description: "Lossless quality with transparency"),
        FormatOption(name: "JPEG", ext: "jpg", icon: "photo", category: .image, description: "Standard compressed photo"),
        FormatOption(name: "HEIC", ext: "heic", icon: "apple.logo", category: .image, description: "High efficiency Apple photo"),
        FormatOption(name: "GIF", ext: "gif", icon: "play.circle.fill", category: .image, description: "Animated or static graphic"),
        FormatOption(name: "PDF", ext: "pdf", icon: "doc.richtext", category: .image, description: "Single-page printable PDF"),
        FormatOption(name: "TIFF", ext: "tiff", icon: "square.fill", category: .image, description: "Uncompressed archival quality"),
        FormatOption(name: "BMP", ext: "bmp", icon: "paintpalette.fill", category: .image, description: "Standard Windows bitmap")
    ]

    // Videos
    public static let videoFormats: [FormatOption] = [
        FormatOption(name: "MP4", ext: "mp4", icon: "video.fill", category: .video, description: "Universal H.264 video"),
        FormatOption(name: "MOV", ext: "mov", icon: "apple.logo", category: .video, description: "QuickTime Apple video"),
        FormatOption(name: "WebM", ext: "webm", icon: "network", category: .video, description: "Modern web streaming video"),
        FormatOption(name: "GIF", ext: "gif", icon: "film", category: .video, description: "Short animated looping GIF"),
        FormatOption(name: "MP3", ext: "mp3", icon: "music.note", category: .video, description: "Extract audio track only"),
        FormatOption(name: "MKV", ext: "mkv", icon: "archivebox.fill", category: .video, description: "Matroska container video")
    ]

    // Audio
    public static let audioFormats: [FormatOption] = [
        FormatOption(name: "MP3", ext: "mp3", icon: "waveform", category: .audio, description: "Universal compressed audio"),
        FormatOption(name: "M4A", ext: "m4a", icon: "apple.logo", category: .audio, description: "Apple AAC high quality"),
        FormatOption(name: "WAV", ext: "wav", icon: "waveform.path.ecg", category: .audio, description: "Lossless uncompressed audio"),
        FormatOption(name: "FLAC", ext: "flac", icon: "music.quarternote.3", category: .audio, description: "Lossless studio compressed audio"),
        FormatOption(name: "OGG", ext: "ogg", icon: "speaker.wave.3.fill", category: .audio, description: "Open Vorbis audio"),
        FormatOption(name: "AAC", ext: "aac", icon: "hifispeaker.fill", category: .audio, description: "Advanced Audio Coding")
    ]

    // Documents
    public static let documentFormats: [FormatOption] = [
        FormatOption(name: "PNG Pages", ext: "png", icon: "photo.stack", category: .document, description: "Export each page as PNG"),
        FormatOption(name: "JPEG Pages", ext: "jpg", icon: "photo.on.rectangle", category: .document, description: "Export each page as JPEG"),
        FormatOption(name: "Text Extract", ext: "txt", icon: "text.alignleft", category: .document, description: "Extract plain text content"),
        FormatOption(name: "Compress PDF", ext: "pdf", icon: "arrow.down.doc.fill", category: .document, description: "Reduce PDF file size")
    ]

    // Tools for Option+Shift
    public static let imageTools: [ToolOption] = [
        ToolOption(id: "compress_image", name: "Compress", icon: "arrow.down.forward.and.arrow.up.backward", description: "Reduce file size without quality loss"),
        ToolOption(id: "resize_50", name: "50% Scale", icon: "arrow.down.right.and.arrow.up.left", description: "Resize dimensions to half"),
        ToolOption(id: "grayscale", name: "Grayscale", icon: "circle.lefthalf.filled", description: "Convert to black & white"),
        ToolOption(id: "to_pdf", name: "Make PDF", icon: "doc.fill", description: "Wrap image in a clean PDF")
    ]

    public static let videoTools: [ToolOption] = [
        ToolOption(id: "compress_video", name: "Compress", icon: "arrow.down.forward.and.arrow.up.backward", description: "Optimize video for web/Discord"),
        ToolOption(id: "video_to_gif", name: "Make GIF", icon: "film", description: "Turn short clip into GIF"),
        ToolOption(id: "extract_audio", name: "Extract MP3", icon: "music.note", description: "Rip audio from video track"),
        ToolOption(id: "mute_video", name: "Mute", icon: "speaker.slash.fill", description: "Remove audio track completely")
    ]

    public static func detectCategory(for url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()

        // Image extensions
        let imageExts: Set<String> = ["jpg", "jpeg", "png", "webp", "heic", "heif", "gif", "tiff", "tif", "bmp", "svg", "ico", "avif", "raw", "cr2", "nef"]
        if imageExts.contains(ext) { return .image }

        // Video extensions
        let videoExts: Set<String> = ["mp4", "mov", "webm", "mkv", "avi", "m4v", "flv", "wmv", "3gp", "ts"]
        if videoExts.contains(ext) { return .video }

        // Audio extensions
        let audioExts: Set<String> = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "opus", "aiff", "aif", "wma"]
        if audioExts.contains(ext) { return .audio }

        // Document extensions
        let docExts: Set<String> = ["pdf", "docx", "doc", "txt", "rtf", "md"]
        if docExts.contains(ext) { return .document }

        // Fallback to UTType
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) { return .video }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .pdf) { return .document }
        }

        return .unknown
    }

    public static func formats(for category: FileCategory) -> [FormatOption] {
        switch category {
        case .image: return imageFormats
        case .video: return videoFormats
        case .audio: return audioFormats
        case .document: return documentFormats
        case .unknown: return imageFormats // fallback
        }
    }

    public static func tools(for category: FileCategory) -> [ToolOption] {
        switch category {
        case .image: return imageTools
        case .video: return videoTools
        default: return imageTools
        }
    }
}
