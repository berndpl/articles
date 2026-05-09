import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()
    @State private var folderSetupError: String? = nil
    @State private var isSelectingFolder = false

    var body: some View {
        Group {
            if appState.hasSelectedFolder {
                NavigationStack(path: $navigationPath) {
                    HistoryView()
                        .navigationDestination(for: Article.self) { article in
                            ReaderView(article: article)
                        }
                }
            } else {
                FolderSetupView(
                    errorMessage: folderSetupError,
                    isSelecting: isSelectingFolder
                ) { url in
                    Task { await selectFolder(url) }
                }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "articles",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let uuid = UUID(uuidString: idString) else { return }
            appState.pendingArticleID = uuid
        }
        .onChange(of: appState.pendingArticleID) { _, newID in
            guard let id = newID else { return }
            appState.pendingArticleID = nil
            let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
            guard let article = try? modelContext.fetch(descriptor).first else { return }
            navigationPath.removeLast(navigationPath.count)
            navigationPath.append(article)
        }
    }

    @MainActor
    private func selectFolder(_ url: URL) async {
        guard !isSelectingFolder else { return }
        isSelectingFolder = true
        folderSetupError = nil
        defer { isSelectingFolder = false }

        do {
            try ArticleFolderStore.setFolder(url)
            let repository = ArticleRepository(context: modelContext)
            try repository.exportReadyArticlesToFolder()
            try repository.indexFolderArticles()
            appState.refreshFolderState()
        } catch {
            ArticleFolderStore.clearFolder()
            folderSetupError = error.localizedDescription
            appState.refreshFolderState()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedStore.makePreviewContainer())
}
