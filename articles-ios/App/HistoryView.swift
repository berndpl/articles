import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\Article.updatedAt, order: .reverse)]) private var articles: [Article]

    @State private var isRefreshing = false
    @State private var pasteError: String? = nil
    @State private var showPasteError = false

    var body: some View {
        List {
            if articles.isEmpty {
                ContentUnavailableView(
                    "No Articles Yet",
                    systemImage: "square.and.arrow.down",
                    description: Text("Share a webpage URL from Safari or another app to save it here.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(articles) { article in
                    NavigationLink(value: article) {
                        ArticleRowView(article: article)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(article)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if article.canRetry {
                            Button {
                                retry(article)
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Articles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Button {
                        Task { await resumeIncomplete() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    pasteURL()
                } label: {
                    Label("Paste URL", systemImage: "doc.on.clipboard")
                }
            }
        }
        .alert("Invalid URL", isPresented: $showPasteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pasteError ?? "The clipboard doesn't contain a valid URL.")
        }
        .task {
            await resumeIncomplete()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await resumeIncomplete() }
        }
    }

    private func pasteURL() {
        let text = UIPasteboard.general.string ?? ""
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http" || url.scheme == "https" else {
            pasteError = text.isEmpty ? "The clipboard is empty." : "\"\(text)\" is not a valid URL."
            showPasteError = true
            return
        }
        Task {
            await ArticleIngestionService.ingest(url: url, in: modelContext)
        }
    }

    @MainActor
    private func delete(_ article: Article) {
        modelContext.delete(article)
        try? modelContext.save()
    }

    private func retry(_ article: Article) {
        Task {
            await ArticleIngestionService.retry(article, in: modelContext)
        }
    }

    @MainActor
    private func resumeIncomplete() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await ArticleIngestionService.resumeIncompleteArticles(in: modelContext)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(SharedStore.makePreviewContainer())
}
