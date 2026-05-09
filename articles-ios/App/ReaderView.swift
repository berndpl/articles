import SwiftData
import SwiftUI

enum ExtractorType: String, CaseIterable, Identifiable {
    case swiftSoup = "SwiftSoup"
    case readability = "Readability"
    var id: Self { self }
}

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var article: Article

    @State private var selectedExtractor: ExtractorType = .swiftSoup
    @State private var previewMarkdown: String? = nil
    @State private var isExtracting = false
    @State private var extractionError: String? = nil
    @State private var speech = ArticleSpeechSynthesizer()
    @State private var isChapterizing = false
    @State private var chapterError: String? = nil
    @State private var isChapterizerAvailable = false
    @State private var chapterizerUnavailableMessage: String? = nil
    @State private var requestedChapterStart: Int? = nil
    @State private var autoChapterizeAttempted = false

    var body: some View {
        Group {
            switch article.status {
            case .ready:
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            extractorPicker
                            chapterStatusView
                            if isExtracting {
                                ProgressView("Extracting…")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else if let error = extractionError {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.callout)
                            } else {
                                ArticleBodyView(blocks: displayBlocks)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .onChange(of: requestedChapterStart) { _, newValue in
                        guard let newValue else { return }
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                        requestedChapterStart = nil
                    }
                }
            case .failed:
                ContentUnavailableView(
                    "Couldn't Extract Article",
                    systemImage: "exclamationmark.triangle",
                    description: Text(article.errorMessage ?? "The page couldn't be converted into a readable article.")
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Retry") {
                            Task {
                                await ArticleIngestionService.retry(article, in: modelContext)
                            }
                        }
                    }
                }
            case .pending, .extracting:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text(article.status == .pending ? "Waiting to process..." : "Extracting article...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if article.status == .ready {
                ToolbarItem(placement: .principal) {
                    chapterTitleMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        speech.toggle(displayMarkdown)
                    } label: {
                        Image(systemName: speech.state == .speaking ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(speech.state == .speaking ? "Pause" : "Read aloud")
                }
            }
        }
        .onAppear {
            refreshChapterizerAvailability()
            runAutomaticChapterizeIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshChapterizerAvailability()
            runAutomaticChapterizeIfNeeded()
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var displayMarkdown: String {
        previewMarkdown ?? article.bodyContent
    }

    private var displayBlocks: [ArticleMarkdownSegmenter.Block] {
        ArticleMarkdownSegmenter.blocks(from: displayMarkdown)
    }

    private var chapterizer: ArticleChapterizer {
        ArticleChapterizer()
    }

    @ViewBuilder
    private var chapterTitleMenu: some View {
        Menu {
            let chapters = article.chapters
            if !chapters.isEmpty {
                ForEach(chapters) { chapter in
                    Button {
                        requestedChapterStart = chapter.startParagraphIndex
                        speech.speak(article.bodyContent, fromParagraphIndex: chapter.startParagraphIndex)
                    } label: {
                        Label(chapter.title, systemImage: "play.circle")
                    }
                }
            } else if isChapterizerAvailable {
                Button {
                    Task { await chapterize() }
                } label: {
                    Label(isChapterizing ? "Chapterizing" : "Chapterize", systemImage: "sparkles")
                }
                .disabled(isChapterizing)
            } else {
                Button {
                    refreshChapterizerAvailability()
                    runAutomaticChapterizeIfNeeded()
                } label: {
                    Label(chapterizerUnavailableMessage ?? "Chapterize unavailable", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(article.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 220)
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Article chapters")
    }

    @ViewBuilder
    private var extractorPicker: some View {
        Picker("Extractor", selection: $selectedExtractor) {
            ForEach(ExtractorType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedExtractor) { _, newValue in
            switch newValue {
            case .swiftSoup:
                previewMarkdown = nil
                extractionError = nil
            case .readability:
                Task { await extractWithReadability() }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.displayTitle)
                .font(.title)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Label(article.sourceDomain, systemImage: "globe")
                Label(article.updatedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Link(destination: article.sourceURLValue) {
                Label("Open Original", systemImage: "safari")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chapterStatusView: some View {
        let chapters = article.chapters
        if !chapters.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if isChapterizing {
                    Label("Chapterizing", systemImage: "sparkles")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !isChapterizerAvailable, let chapterizerUnavailableMessage {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(chapterizerUnavailableMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Button {
                            refreshChapterizerAvailability()
                            runAutomaticChapterizeIfNeeded()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh Chapterize availability")
                    }
                }

                if let chapterError {
                    Text(chapterError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func extractWithReadability() async {
        guard let url = URL(string: article.sourceURL) else { return }
        isExtracting = true
        previewMarkdown = nil
        extractionError = nil
        defer { isExtracting = false }
        do {
            let result = try await ReadabilityExtractor.extract(from: url)
            previewMarkdown = HTMLToMarkdownConverter.convert(result.bodyHTML, title: result.title)
        } catch {
            extractionError = "Readability failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func chapterize() async {
        guard !isChapterizing else { return }
        isChapterizing = true
        chapterError = nil
        defer { isChapterizing = false }

        do {
            let chapters = try await chapterizer.chapterize(title: article.displayTitle, markdown: article.bodyContent)
            article.chapters = chapters
            try modelContext.save()
            persistChaptersToArticleFile(chapters)
        } catch {
            chapterError = error.localizedDescription
        }
    }

    @MainActor
    private func persistChaptersToArticleFile(_ chapters: [ArticleChapter]) {
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

        do {
            let folderArticle = try ArticleFolderStore.write(document, replacing: article.fileName)
            article.fileName = ArticleFolderStore.filename(for: folderArticle.fileURL)
            article.fileModifiedAt = folderArticle.modifiedAt
            try modelContext.save()
        } catch {
            chapterError = "Chapters saved locally, but couldn't update the article file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func refreshChapterizerAvailability() {
        isChapterizerAvailable = chapterizer.isAvailable
        chapterizerUnavailableMessage = chapterizer.unavailableMessage
    }

    @MainActor
    private func runAutomaticChapterizeIfNeeded() {
        guard article.status == .ready,
              article.chapters.isEmpty,
              previewMarkdown == nil,
              isChapterizerAvailable,
              !isChapterizing,
              !autoChapterizeAttempted else { return }
        autoChapterizeAttempted = true
        Task { await chapterize() }
    }
}

// MARK: - Voice Picker

private struct VoiceRow: View {
    let voice: ArticleSpeechSynthesizer.VoiceInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(voice.name)
                    Text(voice.qualityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .tint(.primary)
    }
}

struct VoicePickerView: View {
    @Bindable var speech: ArticleSpeechSynthesizer
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredVoices: [ArticleSpeechSynthesizer.VoiceInfo] {
        speech.availableVoices.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredVoices) { voice in
                VoiceRow(voice: voice, isSelected: speech.selectedVoiceID == voice.id) {
                    speech.selectedVoiceID = voice.id
                    speech.restartIfNeeded()
                    dismiss()
                }
            }
            .searchable(text: $searchText, prompt: "Search voices")
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("System Default") {
                        speech.selectedVoiceID = nil
                        speech.restartIfNeeded()
                        dismiss()
                    }
                    .disabled(speech.selectedVoiceID == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct VoiceSummaryRow: View {
    @Bindable var speech: ArticleSpeechSynthesizer
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Label("Voice", systemImage: "person.wave.2")
                Spacer()
                Text(speech.selectedVoiceName ?? "System Default")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(article: .previewReady)
    }
    .modelContainer(SharedStore.makePreviewContainer())
}
