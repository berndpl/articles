import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HistoryView()
                .navigationDestination(for: Article.self) { article in
                    ReaderView(article: article)
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
}

#Preview {
    ContentView()
        .modelContainer(SharedStore.makePreviewContainer())
}
