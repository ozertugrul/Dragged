import SwiftUI
import AppKit

public struct QuickConverterView: View {
    @ObservedObject var engine = ConversionEngine.shared
    @State private var selectedCategory: FileCategory = .image
    @State private var selectedFormat: String = "webp"
    @State private var isTargeted: Bool = false
    @State private var droppedFiles: [URL] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Dragged")
                        .font(.system(size: 15, weight: .bold))
                    Text("Instant Local File Converter & Radial Menu")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    if let first = droppedFiles.first {
                        RadialWindow.shared.showAtCursor(with: first, toolMode: false)
                    } else {
                        RadialWindow.shared.showAtCursor(with: nil, toolMode: false)
                    }
                }) {
                    Label("Preview Radial Menu", systemImage: "circle.circle")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Big Drag & Drop Area
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.orange.opacity(0.12) : Color.black.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isTargeted ? Color.orange : Color.gray.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 2, dash: [8])
                                    )
                            )
                            .frame(height: 160)

                        VStack(spacing: 8) {
                            if droppedFiles.count == 1, let file = droppedFiles.first {
                                Image(systemName: FormatRegistry.detectCategory(for: file).icon)
                                    .font(.system(size: 38))
                                    .foregroundColor(.orange)

                                Text(file.lastPathComponent)
                                    .font(.system(size: 14, weight: .bold))

                                Text(file.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal, 40)
                            } else if droppedFiles.count > 1 {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.orange)

                                Text("\(droppedFiles.count) Files Selected (Batch Mode)")
                                    .font(.system(size: 14, weight: .bold))

                                Text(droppedFiles.map { $0.lastPathComponent }.prefix(3).joined(separator: ", ") + (droppedFiles.count > 3 ? "..." : ""))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.orange)

                                Text("Drag & Drop any file(s) here")
                                    .font(.system(size: 14, weight: .bold))

                                Text("Or drag files anywhere while holding Shift")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    Task {
                                        _ = await engine.convertClipboardImage(to: selectedFormat)
                                    }
                                }) {
                                    Label("Convert from Clipboard", systemImage: "doc.on.clipboard.fill")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.link)
                                .padding(.top, 2)
                            }
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                        var loadedURLs: [URL] = []
                        let group = DispatchGroup()

                        for provider in providers {
                            group.enter()
                            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        loadedURLs.append(url)
                                    }
                                }
                                group.leave()
                            }
                        }

                        group.notify(queue: .main) {
                            if !loadedURLs.isEmpty {
                                self.droppedFiles = loadedURLs
                                if let first = loadedURLs.first {
                                    self.selectedCategory = FormatRegistry.detectCategory(for: first)
                                    if let firstFmt = FormatRegistry.formats(for: self.selectedCategory).first {
                                        self.selectedFormat = firstFmt.ext
                                    }
                                }
                            }
                        }
                        return true
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Format Selection Pills
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Convert To:")
                                .font(.system(size: 13, weight: .bold))

                            Spacer()

                            // Category Switcher
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(FileCategory.allCases.filter { $0 != .unknown }) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                        }

                        // Grid of available formats
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                            ForEach(FormatRegistry.formats(for: selectedCategory)) { fmt in
                                Button(action: {
                                    selectedFormat = fmt.ext
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: fmt.icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(selectedFormat == fmt.ext ? .white : .orange)
                                        Text(fmt.name)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(selectedFormat == fmt.ext ? .white : .primary)
                                        Text(fmt.description)
                                            .font(.system(size: 8))
                                            .foregroundColor(selectedFormat == fmt.ext ? .white.opacity(0.8) : .secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                selectedFormat == fmt.ext
                                                ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyShapeStyle(Color.black.opacity(0.05))
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedFormat == fmt.ext ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Action Tools (Compress, Trim, etc.)
                        Text("Quick Actions (Option + Shift):")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.top, 6)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                            ForEach(FormatRegistry.tools(for: selectedCategory)) { tool in
                                Button(action: {
                                    if let file = droppedFiles.first {
                                        Task {
                                            _ = await engine.executeTool(actionId: tool.id, on: file)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: tool.icon)
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(tool.name)
                                                .font(.system(size: 11, weight: .bold))
                                            Text(tool.description)
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(droppedFiles.isEmpty)
                            }
                        }

                        // Convert Button (supports single or batch)
                        Button(action: {
                            guard !droppedFiles.isEmpty else { return }
                            Task {
                                if droppedFiles.count == 1, let single = droppedFiles.first {
                                    _ = await engine.convert(file: single, to: selectedFormat)
                                } else {
                                    _ = await engine.convertBatch(files: droppedFiles, to: selectedFormat)
                                }
                            }
                        }) {
                            HStack {
                                if engine.isConverting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                    Text(engine.currentFile)
                                        .font(.system(size: 12, weight: .medium))
                                } else {
                                    Image(systemName: "sparkles")
                                    let label = droppedFiles.count > 1
                                        ? "Convert All \(droppedFiles.count) Files to \(selectedFormat.uppercased())"
                                        : "Convert Now (\(selectedFormat.uppercased()))"
                                    Text(label)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(droppedFiles.isEmpty || engine.isConverting)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)

                    // Recent Conversions List
                    if !engine.recentConversions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Conversions")
                                .font(.system(size: 13, weight: .bold))

                            ForEach(engine.recentConversions) { item in
                                HStack {
                                    Image(systemName: item.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundColor(item.isSuccess ? .green : .red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.destinationURL.lastPathComponent)
                                            .font(.system(size: 12, weight: .medium))
                                        HStack(spacing: 6) {
                                            Text(item.targetFormat)
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .cornerRadius(4)
                                            Text(formatBytes(item.destinationSize))
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if item.isSuccess {
                                        Button(action: {
                                            NSWorkspace.shared.activateFileViewerSelecting([item.destinationURL])
                                        }) {
                                            Image(systemName: "folder")
                                                .font(.system(size: 13))
                                        }
                                        .help("Show in Finder")
                                    }
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 540, minHeight: 640)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
