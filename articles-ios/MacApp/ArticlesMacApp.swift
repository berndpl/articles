import AppKit
import SwiftData
import SwiftUI

@main
struct ArticlesMacApp: App {
    let modelContainer = SharedStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            MacSettingsView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
    }
}

struct MacSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var folderPath = ArticleFolderStore.displayPath()
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Articles")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Choose the shared folder used by Safari, iOS, and the CLI.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(folderPath == nil ? "No folder selected" : "Selected Folder")
                    .font(.headline)
                Text(folderPath ?? "Choose your iCloud Articles folder before using Save to Articles from Safari.")
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            HStack {
                Button {
                    chooseFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                Button {
                    reindexFolder()
                } label: {
                    Label("Re-index Folder", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isWorking || folderPath == nil)
            }

            if isWorking {
                ProgressView()
                    .controlSize(.small)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 520, alignment: .leading)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the folder where Articles should save markdown files."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            try ArticleFolderStore.setFolder(url)
            let repository = ArticleRepository(context: modelContext)
            try repository.exportReadyArticlesToFolder()
            try repository.indexFolderArticles()
            folderPath = ArticleFolderStore.displayPath()
            statusMessage = "Folder ready."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reindexFolder() {
        isWorking = true
        defer { isWorking = false }

        do {
            try ArticleRepository(context: modelContext).indexFolderArticles()
            folderPath = ArticleFolderStore.displayPath()
            statusMessage = "Folder re-indexed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
