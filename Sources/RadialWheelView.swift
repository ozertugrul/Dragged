import SwiftUI
import AppKit

// MARK: - Wheel Category Definition
public enum WheelCategory: Int, CaseIterable {
    case formats = 0
    case tools = 1
    case media = 2
    case documents = 3

    public var title: String {
        switch self {
        case .formats: return "IMAGE FORMATS"
        case .tools: return "TOOLS & EDIT"
        case .media: return "VIDEO & AUDIO"
        case .documents: return "PDF & DOCUMENTS"
        }
    }
}

public struct WheelItem {
    public let name: String
    public let id: String
    public let icon: String?
    public let hint: String?
    public let isTool: Bool

    public init(name: String, id: String, icon: String? = nil, hint: String? = nil, isTool: Bool = false) {
        self.name = name
        self.id = id
        self.icon = icon
        self.hint = hint
        self.isTool = isTool
    }
}

// MARK: - Rounded Annular Petal Shape
struct RoundedPetalShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var gapAngle: Double = 3.2

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        let sAngle = Angle(degrees: startAngle.degrees + gapAngle)
        let eAngle = Angle(degrees: endAngle.degrees - gapAngle)

        let sRad = sAngle.radians
        let eRad = eAngle.radians

        let innerStart = CGPoint(x: center.x + innerRadius * cos(sRad), y: center.y + innerRadius * sin(sRad))
        let outerStart = CGPoint(x: center.x + outerRadius * cos(sRad), y: center.y + outerRadius * sin(sRad))
        let innerEnd = CGPoint(x: center.x + innerRadius * cos(eRad), y: center.y + innerRadius * sin(eRad))

        path.move(to: innerStart)
        path.addLine(to: outerStart)
        path.addArc(center: center, radius: outerRadius, startAngle: sAngle, endAngle: eAngle, clockwise: false)
        path.addLine(to: innerEnd)
        path.addArc(center: center, radius: innerRadius, startAngle: eAngle, endAngle: sAngle, clockwise: true)
        path.closeSubpath()

        return path
    }
}

// MARK: - Radial Wheel State Model with Multi-Page / Scroll Support
public class RadialWheelState: ObservableObject {
    public static let shared = RadialWheelState()

    @Published public var activeCategory: WheelCategory = .formats
    @Published public var hoveredIndex: Int? = nil // 0..<8 for petals, 999 for center pill
    @Published public var currentFiles: [URL] = []
    @Published public var fileThumbnail: NSImage? = nil

    public let totalPetals = 8
    public let innerRadius: CGFloat = 68
    public let outerRadius: CGFloat = 162
    public let totalSize: CGFloat = 440

    // Cooldown for trackpad/mouse scroll gestures
    private var lastScrollTime: Date = Date.distantPast
    private var accumulatedDelta: CGFloat = 0.0

    // --- Page 0: Image Formats (Image 1) ---
    public let formatPetals: [WheelItem] = [
        WheelItem(name: "PNG", id: "png", hint: "Lossless · transparency"),
        WheelItem(name: "WEBP", id: "webp", hint: "Smallest for web"),
        WheelItem(name: "HEIC", id: "heic", hint: "iPhone format"),
        WheelItem(name: "GIF", id: "gif", hint: "Animated · web"),
        WheelItem(name: "AVIF", id: "avif", hint: "Next-gen, tiny"),
        WheelItem(name: "BMP", id: "bmp", hint: "Uncompressed"),
        WheelItem(name: "PDF", id: "pdf", hint: "Document pages"),
        WheelItem(name: "DOCX", id: "docx", hint: "Editable Word")
    ]
    public let formatCenter = WheelItem(name: "TIFF", id: "tiff", hint: "Print · archival")

    // --- Page 1: Tools & Edit (Image 2) ---
    public let toolPetals: [WheelItem] = [
        WheelItem(name: "COMPRESS", id: "compress_image", icon: "arrow.down.forward.and.arrow.up.backward", hint: "Shrink file size", isTool: true),
        WheelItem(name: "METADATA", id: "metadata", icon: "tag.fill", hint: "Strip GPS & EXIF", isTool: true),
        WheelItem(name: "EDIT", id: "edit", icon: "slider.horizontal.3", hint: "Light · colour · rotate", isTool: true),
        WheelItem(name: "ANNOTATE", id: "annotate", icon: "pencil.tip.crop.circle", hint: "Arrows · text · steps", isTool: true),
        WheelItem(name: "REMOVE BG", id: "remove_bg", icon: "sparkles", hint: "Cut out subject", isTool: true),
        WheelItem(name: "PREVIEW", id: "preview", icon: "eye.fill", hint: "Quick look", isTool: true),
        WheelItem(name: "CROP", id: "crop", icon: "crop", hint: "Trim to ratio", isTool: true),
        WheelItem(name: "REDACT", id: "redact", icon: "eye.slash.fill", hint: "Hide sensitive info", isTool: true)
    ]
    public let toolCenter = WheelItem(name: "ADD BG", id: "add_bg", icon: "square.dashed", hint: "Solid or gradient", isTool: true)

    // --- Page 2: Video & Audio Media ---
    public let mediaPetals: [WheelItem] = [
        WheelItem(name: "MP4", id: "to_mp4", icon: "video.fill", hint: "Universal video", isTool: true),
        WheelItem(name: "GIF", id: "video_to_gif", icon: "play.square.fill", hint: "Clip to GIF", isTool: true),
        WheelItem(name: "MP3", id: "extract_audio", icon: "music.note", hint: "Extract sound", isTool: true),
        WheelItem(name: "WAV", id: "to_wav", icon: "waveform", hint: "Lossless audio", isTool: true),
        WheelItem(name: "MOV", id: "to_mov", icon: "film.fill", hint: "QuickTime video", isTool: true),
        WheelItem(name: "WEBM", id: "to_webm", icon: "play.rectangle.fill", hint: "HTML5 video", isTool: true),
        WheelItem(name: "M4A", id: "to_m4a", icon: "headphones", hint: "Apple audio", isTool: true),
        WheelItem(name: "COMPRESS", id: "compress_video", icon: "arrow.down.right.and.arrow.up.left", hint: "Reduce bitrate", isTool: true)
    ]
    public let mediaCenter = WheelItem(name: "MUTE", id: "mute_video", icon: "speaker.slash.fill", hint: "Strip audio track", isTool: true)

    // --- Page 3: PDF & Documents ---
    public let docPetals: [WheelItem] = [
        WheelItem(name: "TO PDF", id: "to_pdf", icon: "doc.text.fill", hint: "Export to PDF", isTool: true),
        WheelItem(name: "COMPRESS", id: "compress_pdf", icon: "arrow.down.circle.fill", hint: "Shrink PDF size", isTool: true),
        WheelItem(name: "SPLIT", id: "split_pdf", icon: "scissors", hint: "Separate pages", isTool: true),
        WheelItem(name: "MERGE", id: "merge_pdf", icon: "doc.on.doc.fill", hint: "Combine into one", isTool: true),
        WheelItem(name: "OCR TEXT", id: "ocr_pdf", icon: "text.viewfinder", hint: "Recognize text", isTool: true),
        WheelItem(name: "TO IMAGES", id: "pdf_to_images", icon: "photo.stack.fill", hint: "Page by page images", isTool: true),
        WheelItem(name: "TO WORD", id: "pdf_to_docx", icon: "doc.richtext.fill", hint: "Convert to DOCX", isTool: true),
        WheelItem(name: "PRINT", id: "print_doc", icon: "printer.fill", hint: "Send to printer", isTool: true)
    ]
    public let docCenter = WheelItem(name: "PREVIEW", id: "preview", icon: "eye.fill", hint: "View document", isTool: true)

    // Active items for current category
    public var currentPetals: [WheelItem] {
        switch activeCategory {
        case .formats: return formatPetals
        case .tools: return toolPetals
        case .media: return mediaPetals
        case .documents: return docPetals
        }
    }

    public var currentCenter: WheelItem {
        switch activeCategory {
        case .formats: return formatCenter
        case .tools: return toolCenter
        case .media: return mediaCenter
        case .documents: return docCenter
        }
    }

    public func setFiles(_ files: [URL]) {
        self.currentFiles = files
        if let first = files.first {
            let icon = NSWorkspace.shared.icon(forFile: first.path)
            icon.size = NSSize(width: 48, height: 48)
            self.fileThumbnail = icon
            smartSelectCategory(for: first)
        } else {
            self.fileThumbnail = nil
        }
    }

    public func smartSelectCategory(for url: URL) {
        let ext = url.pathExtension.lowercased()
        let videoExts = ["mp4", "mov", "m4v", "mkv", "avi", "webm", "wmv", "flv"]
        let audioExts = ["mp3", "wav", "m4a", "aac", "flac", "ogg", "aiff"]
        let docExts = ["pdf", "doc", "docx", "txt", "rtf"]

        if videoExts.contains(ext) || audioExts.contains(ext) {
            self.activeCategory = .media
        } else if docExts.contains(ext) {
            self.activeCategory = .documents
        } else {
            self.activeCategory = .formats
        }
    }

    // Scroll gesture handling (Trackpad / Mouse Wheel)
    public func handleScroll(delta: CGFloat) {
        accumulatedDelta += delta
        let threshold: CGFloat = 3.0
        guard Date().timeIntervalSince(lastScrollTime) > 0.18 else { return }

        if accumulatedDelta < -threshold {
            lastScrollTime = Date()
            accumulatedDelta = 0
            nextPage()
        } else if accumulatedDelta > threshold {
            lastScrollTime = Date()
            accumulatedDelta = 0
            previousPage()
        }
    }

    public func nextPage() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            let all = WheelCategory.allCases
            let nextIdx = (activeCategory.rawValue + 1) % all.count
            activeCategory = all[nextIdx]
            hoveredIndex = nil
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    public func previousPage() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            let all = WheelCategory.allCases
            let prevIdx = (activeCategory.rawValue - 1 + all.count) % all.count
            activeCategory = all[prevIdx]
            hoveredIndex = nil
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    public func updateHover(point: CGPoint) {
        let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        // Center pill zone: width 98, height 46
        if abs(dx) < 50 && abs(dy) < 24 {
            if hoveredIndex != 999 {
                DispatchQueue.main.async {
                    self.hoveredIndex = 999
                }
            }
            return
        }

        if distance < (innerRadius - 4) || distance > (outerRadius + 30) {
            if hoveredIndex != nil {
                DispatchQueue.main.async {
                    self.hoveredIndex = nil
                }
            }
            return
        }

        let angleDeg = atan2(dy, dx) * 180.0 / .pi
        let slice = 45.0
        var normalized = angleDeg + 112.5
        while normalized < 0 { normalized += 360.0 }
        while normalized >= 360.0 { normalized -= 360.0 }
        let idx = Int(normalized / slice) % totalPetals

        if hoveredIndex != idx {
            DispatchQueue.main.async {
                self.hoveredIndex = idx
            }
        }
    }

    public func triggerAction(at index: Int?, files: [URL]? = nil) {
        let filesToUse = files ?? currentFiles
        guard let idx = index else { return }

        let item = (idx == 999) ? currentCenter : currentPetals[idx]

        if item.isTool {
            executeTool(id: item.id, files: filesToUse)
        } else {
            convert(to: item.id, files: filesToUse)
        }
    }

    private func convert(to ext: String, files: [URL]) {
        guard !files.isEmpty else {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
        Task {
            if files.count == 1, let first = files.first {
                _ = await ConversionEngine.shared.convert(file: first, to: ext)
            } else {
                _ = await ConversionEngine.shared.convertBatch(files: files, to: ext)
            }
        }
    }

    private func executeTool(id: String, files: [URL]) {
        guard let first = files.first else {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
        Task {
            _ = await ConversionEngine.shared.executeTool(actionId: id, on: first)
        }
    }
}

// MARK: - Radial Wheel View with Category Header and Scroll Indicators
public struct RadialWheelView: View {
    @ObservedObject public var state: RadialWheelState
    @ObservedObject public var themeManager: ThemeManager

    public init(state: RadialWheelState = .shared, themeManager: ThemeManager = .shared) {
        self.state = state
        self.themeManager = themeManager
    }

    public var body: some View {
        let theme = themeManager.currentTheme

        ZStack {
            // 1. Ambient Frosted Glass Outer Ring (Liquid Glass)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: state.outerRadius * 2 + 18, height: state.outerRadius * 2 + 18)
                .overlay(
                    Circle()
                        .fill(theme.ringFill)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: theme.ringStrokeGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.black.opacity(theme.isDark ? 0.45 : 0.22), radius: 26, x: 0, y: 12)

            // 2. Inner Ring Boundary
            Circle()
                .stroke(theme.innerRingBorder, lineWidth: 1.5)
                .frame(width: state.innerRadius * 2, height: state.innerRadius * 2)

            // 3. 8 Segmented Petals for Current Category
            ForEach(0..<state.totalPetals, id: \.self) { index in
                let (startAngle, endAngle) = petalAngles(for: index)
                let isHovered = state.hoveredIndex == index
                let item = state.currentPetals[index]

                ZStack {
                    // 1. Frosted Liquid Glass Base
                    RoundedPetalShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: state.innerRadius + 4,
                        outerRadius: isHovered ? state.outerRadius + 6 : state.outerRadius,
                        gapAngle: 3.2
                    )
                    .fill(.ultraThinMaterial)

                    // 2. Translucent Glass Tint or Blooming Hover Gradient
                    RoundedPetalShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: state.innerRadius + 4,
                        outerRadius: isHovered ? state.outerRadius + 6 : state.outerRadius,
                        gapAngle: 3.2
                    )
                    .fill(
                        isHovered
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: theme.activeGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(theme.petalDefaultFill)
                    )
                    .overlay(
                        RoundedPetalShape(
                            startAngle: startAngle,
                            endAngle: endAngle,
                            innerRadius: state.innerRadius + 4,
                            outerRadius: isHovered ? state.outerRadius + 6 : state.outerRadius,
                            gapAngle: 3.2
                        )
                        .stroke(
                            isHovered
                            ? AnyShapeStyle(Color.white.opacity(0.95))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(theme.isDark ? 0.40 : 0.75),
                                        Color.white.opacity(theme.isDark ? 0.15 : 0.30),
                                        Color.white.opacity(theme.isDark ? 0.05 : 0.10),
                                        Color.white.opacity(theme.isDark ? 0.25 : 0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            ),
                            lineWidth: isHovered ? 1.8 : 1.2
                        )
                    )
                    .shadow(color: isHovered ? theme.hoverGlowColor : Color.black.opacity(0.06), radius: isHovered ? 16 : 3)

                    // Content inside Petal
                    let midAngle = Angle(degrees: Double(index) * 45.0 - 90.0)
                    let dist = (state.innerRadius + state.outerRadius) / 2 + 2
                    let px = dist * CGFloat(cos(midAngle.radians))
                    let py = dist * CGFloat(sin(midAngle.radians))

                    Group {
                        if isHovered && state.fileThumbnail != nil {
                            // Mini thumbnail preview when hovered during drag (Image 1 & 2)
                            VStack(spacing: 2) {
                                Image(nsImage: state.fileThumbnail!)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(4)
                                    .shadow(color: .black.opacity(0.25), radius: 3)

                                Text(item.name)
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        } else if let icon = item.icon {
                            VStack(spacing: 3) {
                                Image(systemName: icon)
                                    .font(.system(size: isHovered ? 18 : 15, weight: .bold))
                                    .foregroundColor(isHovered ? .white : theme.petalTextColor)

                                Text(item.name)
                                    .font(.system(size: isHovered ? 11 : 9.5, weight: .black, design: .rounded))
                                    .foregroundColor(isHovered ? .white : theme.petalTextColor)
                                    .tracking(0.4)
                            }
                        } else {
                            Text(item.name)
                                .font(.system(size: isHovered ? 15.5 : 13.5, weight: .heavy, design: .rounded))
                                .foregroundColor(isHovered ? .white : theme.petalTextColor)
                                .tracking(0.6)
                        }
                    }
                    .offset(x: px, y: py)
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                }
                .onHover { hover in
                    if hover {
                        state.hoveredIndex = index
                    } else if state.hoveredIndex == index {
                        state.hoveredIndex = nil
                    }
                }
                .onTapGesture {
                    state.triggerAction(at: index)
                    RadialWindow.shared.hideWheel()
                }
            }

            // 4. Center Pill with Dynamic Hint (Liquid Glass)
            let isCenterHovered = state.hoveredIndex == 999
            let isHoveredPetal = (state.hoveredIndex != nil && state.hoveredIndex! >= 0 && state.hoveredIndex! < 8)
            let centerItem = state.currentCenter
            let activeItem: WheelItem = isHoveredPetal ? state.currentPetals[state.hoveredIndex!] : centerItem
            let isCenterActive = isCenterHovered || isHoveredPetal

            Button(action: {
                if isHoveredPetal {
                    state.triggerAction(at: state.hoveredIndex!)
                } else {
                    state.triggerAction(at: 999)
                }
                RadialWindow.shared.hideWheel()
            }) {
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .frame(width: 104, height: 48)

                    Capsule()
                        .fill(
                            isCenterActive
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: theme.activeGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(theme.petalDefaultFill)
                        )
                        .frame(width: 104, height: 48)
                        .overlay(
                            Capsule()
                                .stroke(
                                    isCenterActive
                                    ? AnyShapeStyle(Color.white.opacity(0.95))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(theme.isDark ? 0.40 : 0.75),
                                                Color.white.opacity(theme.isDark ? 0.15 : 0.30)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: isCenterActive ? theme.hoverGlowColor : Color.black.opacity(0.12), radius: 10)

                    VStack(spacing: 1.5) {
                        HStack(spacing: 3) {
                            if let icon = activeItem.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(activeItem.name)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(0.5)
                        }
                        Text(isCenterActive ? (activeItem.hint ?? "") : "⇧ SCROLL")
                            .font(.system(size: 7.5, weight: .bold, design: .rounded))
                            .opacity(0.85)
                    }
                    .foregroundColor(isCenterActive ? .white : theme.petalTextColor)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isCenterActive ? 1.06 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCenterActive)
            .onHover { hover in
                if hover {
                    state.hoveredIndex = 999
                } else if state.hoveredIndex == 999 {
                    state.hoveredIndex = nil
                }
            }

            // 5. Category Header Pill with Page Dots & Scroll Indicator (Liquid Glass)
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.dotActiveColor)

                Text(state.activeCategory.title)
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundColor(theme.headerTextColor)
                    .tracking(0.8)

                // 4 glowing category dots
                HStack(spacing: 4) {
                    ForEach(WheelCategory.allCases, id: \.self) { cat in
                        Circle()
                            .fill(cat == state.activeCategory ? theme.dotActiveColor : (theme.isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.18)))
                            .frame(width: cat == state.activeCategory ? 6 : 4, height: cat == state.activeCategory ? 6 : 4)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: state.activeCategory)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(theme.headerBackground))
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.80), Color.white.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(theme.isDark ? 0.35 : 0.16), radius: 6, y: 2)
            )
            .offset(y: -(state.outerRadius + 28))
        }
        .frame(width: state.totalSize, height: state.totalSize)
    }

    private func petalAngles(for index: Int) -> (Angle, Angle) {
        let slice = 45.0
        let startDeg = Double(index) * slice - 90.0 - (slice / 2.0)
        let endDeg = startDeg + slice
        return (Angle(degrees: startDeg), Angle(degrees: endDeg))
    }
}
