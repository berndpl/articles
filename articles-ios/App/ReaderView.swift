import SwiftData
import SwiftUI

enum ExtractorType: String, CaseIterable, Identifiable {
    case swiftSoup = "SwiftSoup"
    case readability = "Readability"
    var id: Self { self }
}

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var article: Article

    @State private var selectedExtractor: ExtractorType = .swiftSoup
    @State private var previewHTML: String? = nil
    @State private var isExtracting = false
    @State private var extractionError: String? = nil

    var body: some View {
        Group {
            switch article.status {
            case .ready:
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        extractorPicker
                        if isExtracting {
                            ProgressView("Extracting…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if let error = extractionError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        } else {
                            ArticleBodyView(html: displayHTML)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
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
        .navigationTitle(article.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayHTML: String {
        previewHTML ?? article.bodyContent
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
                previewHTML = nil
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

    @MainActor
    private func extractWithReadability() async {
        guard let url = URL(string: article.sourceURL) else { return }
        isExtracting = true
        previewHTML = nil
        extractionError = nil
        defer { isExtracting = false }
        do {
            let result = try await ReadabilityExtractor.extract(from: url)
            previewHTML = result.bodyHTML
        } catch {
            extractionError = "Readability failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(article: .previewReady)
    }
    .modelContainer(SharedStore.makePreviewContainer())
}
