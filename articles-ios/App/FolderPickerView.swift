import SwiftUI
import UniformTypeIdentifiers

struct FolderPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct FolderSetupView: View {
    let errorMessage: String?
    let isSelecting: Bool
    let onFolderSelected: (URL) -> Void
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Choose Articles Folder")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Articles saves readable markdown files in a folder you choose so the iOS app and CLI can share one library.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showPicker = true
            } label: {
                if isSelecting {
                    Label("Checking Folder", systemImage: "folder")
                } else {
                    Label("Choose Folder", systemImage: "folder")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSelecting)

            if isSelecting {
                ProgressView()
                    .controlSize(.small)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPicker) {
            FolderPickerView { url in
                showPicker = false
                onFolderSelected(url)
            }
        }
    }
}

struct ArticleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let folderPath: String?
    let isRefreshing: Bool
    let onChangeFolder: () -> Void
    let onReindex: () -> Void
    @State private var speech = ArticleSpeechSynthesizer()
    @State private var showVoicePicker = false

    var body: some View {
        NavigationStack {
            List {
                Section("Speech") {
                    VoiceSummaryRow(speech: speech) {
                        showVoicePicker = true
                    }
                }

                Section("Folder") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(folderPath == nil ? "No folder selected" : "Selected Folder")
                            .font(.headline)
                        if let folderPath {
                            Text(folderPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    Button {
                        onChangeFolder()
                    } label: {
                        Label("Change Folder", systemImage: "folder")
                    }
                }

                Section {
                    Button {
                        onReindex()
                    } label: {
                        if isRefreshing {
                            Label("Re-indexing", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Re-index Folder", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(isRefreshing || folderPath == nil)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(speech: speech)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
