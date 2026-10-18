import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var settings = SettingsManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("Save Location").font(.headline)) {
                Picker("Destination", selection: $settings.destinationMode) {
                    ForEach(SaveDestinationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                if settings.destinationMode == .customFolder {
                    HStack {
                        TextField("Folder", text: $settings.customFolderPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Choose...") {
                            chooseCustomFolder()
                        }
                    }
                    .padding(.leading, 18)
                }
            }
            .padding(.bottom, 10)

            Section(header: Text("Image Compression Quality").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Quality:")
                        Slider(value: Binding(
                            get: { Double(settings.imageQuality) },
                            set: { settings.imageQuality = Int($0) }
                        ), in: 20...100, step: 5)
                        Text("\(settings.imageQuality)%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 44, alignment: .trailing)
                    }
                    Text("Higher quality means larger file sizes. 80% is the recommended sweet spot.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)

            Section(header: Text("Visual Theme").font(.headline)) {
                Picker("Theme", selection: Binding(
                    get: { ThemeManager.shared.currentTheme },
                    set: { ThemeManager.shared.setTheme($0) }
                )) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                Text("Choose between 5 liquid-glass finishes with customized color blooms and contrast.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 10)

            Section(header: Text("Behavior & Feedback").font(.headline)) {
                Toggle("Play sound on completion (Glass)", isOn: $settings.playSound)
                Toggle("Automatically reveal converted file in Finder", isOn: $settings.revealInFinder)
            }
        }
        .padding(24)
        .frame(width: 520, height: 400)
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customFolderPath = url.path
        }
    }
}
