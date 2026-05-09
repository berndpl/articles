import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Query(sort: [SortDescriptor(\Article.updatedAt, order: .reverse)]) private var articles: [Article]

    @State private var isRefreshing = false
    @State private var pasteError: String? = nil
    @State private var showPasteError = false
    @State private var showSettings = false
    @State private var showFolderPicker = false
    @State private var chapterizingArticleIDs: Set<UUID> = []

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
                        ArticleRowView(
                            article: article,
                            isChapterizing: chapterizingArticleIDs.contains(article.id)
                        )
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
        .refreshable {
            await resumeIncomplete()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Button {
                        pasteURL()
                    } label: {
                        Label("Paste URL", systemImage: "doc.on.clipboard")
                    }
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
        .sheet(isPresented: $showSettings) {
            ArticleSettingsView(
                folderPath: appState.folderPath,
                isRefreshing: isRefreshing,
                onChangeFolder: {
                    showSettings = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        showFolderPicker = true
                    }
                },
                onReindex: { Task { await resumeIncomplete() } }
            )
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { url in
                showFolderPicker = false
                Task { await changeFolder(url) }
            }
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
            let article = await ArticleIngestionService.ingest(url: url, in: modelContext)
            await chapterizeIfNeeded(article)
        }
    }

    @MainActor
    private func delete(_ article: Article) {
        try? ArticleRepository(context: modelContext).deleteArticleAndFile(article)
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
        appState.refreshFolderState()
        guard appState.hasSelectedFolder else { return }
        try? ArticleRepository(context: modelContext).indexFolderArticles()
        await ArticleIngestionService.resumeIncompleteArticles(in: modelContext)
        try? ArticleRepository(context: modelContext).indexFolderArticles()
        appState.refreshFolderState()
        await chapterizeReadyArticles()
    }

    @MainActor
    private func changeFolder(_ url: URL) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try ArticleFolderStore.setFolder(url)
            appState.refreshFolderState()
            let repository = ArticleRepository(context: modelContext)
            try repository.exportReadyArticlesToFolder()
            try repository.indexFolderArticles()
            await chapterizeReadyArticles()
        } catch {
            pasteError = error.localizedDescription
            showPasteError = true
        }
    }

    @MainActor
    private func chapterizeReadyArticles() async {
        let chapterizer = ArticleChapterizer()
        guard chapterizer.isAvailable else { return }

        let candidates = articles.filter { article in
            article.status == .ready &&
            article.chapters.isEmpty &&
            !article.bodyContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !chapterizingArticleIDs.contains(article.id)
        }

        for article in candidates {
            await chapterizeIfNeeded(article, using: chapterizer)
        }
    }

    @MainActor
    private func chapterizeIfNeeded(_ article: Article, using chapterizer: ArticleChapterizer = ArticleChapterizer()) async {
        guard article.status == .ready,
              article.chapters.isEmpty,
              !article.bodyContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              chapterizer.isAvailable,
              !chapterizingArticleIDs.contains(article.id) else { return }

        chapterizingArticleIDs.insert(article.id)
        defer { chapterizingArticleIDs.remove(article.id) }

        do {
            let chapters = try await chapterizer.chapterize(title: article.displayTitle, markdown: article.bodyContent)
            article.chapters = chapters
            try modelContext.save()
            try persistChaptersToArticleFile(chapters, for: article)
        } catch {
            // ReaderView still offers retry/error detail; history keeps background processing quiet.
        }
    }

    @MainActor
    private func persistChaptersToArticleFile(_ chapters: [ArticleChapter], for article: Article) throws {
        let document = ArticleMarkdownDocument(
            url: article.sourceURL,
            canonicalURL: article.canonicalURL,
            title: article.displayTitle,
            sourceDomain: article.sourceDomain,
            createdAt: article.createdAt,
            updatedAt: article.updatedAt,
            chapters: chapters,
            markdown: article.bodyContent
        )
        let folderArticle = try ArticleFolderStore.write(document, replacing: article.fileName)
        article.fileName = ArticleFolderStore.filename(for: folderArticle.fileURL)
        article.fileModifiedAt = folderArticle.modifiedAt
        try modelContext.save()
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(SharedStore.makePreviewContainer())
}
