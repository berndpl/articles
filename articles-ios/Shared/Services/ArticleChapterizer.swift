import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ArticleChapterizing {
    var isAvailable: Bool { get }
    var unavailableMessage: String? { get }
    func chapterize(title: String, markdown: String) async throws -> [ArticleChapter]
}

enum ArticleChapterizerError: LocalizedError {
    case unavailable
    case noContent
    case noChapters

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Chapterization is unavailable on this device."
        case .noContent:
            return "This article does not contain enough text to chapterize."
        case .noChapters:
            return "No chapters could be generated for this article."
        }
    }
}

struct ArticleChapterizer: ArticleChapterizing {
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelChapterizer.isAvailable
        }
        #endif
        return false
    }

    var unavailableMessage: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return FoundationModelChapterizer.unavailableMessage
        }
        #endif
        return "Chapterize requires iOS 26 and Apple Intelligence."
    }

    func chapterize(title: String, markdown: String) async throws -> [ArticleChapter] {
        let blocks = ArticleMarkdownSegmenter.blocks(from: markdown)
        guard !blocks.isEmpty else { throw ArticleChapterizerError.noContent }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let chapters = try await FoundationModelChapterizer().chapterize(title: title, blocks: blocks)
            let validated = ArticleChapterValidator.validated(chapters, paragraphCount: blocks.count)
            guard !validated.isEmpty else { throw ArticleChapterizerError.noChapters }
            return validated
        }
        #endif

        throw ArticleChapterizerError.unavailable
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct FoundationModelChapterizer {
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    static var unavailableMessage: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Chapterize requires Apple Intelligence to be enabled."
        case .unavailable(.deviceNotEligible):
            return "Chapterize is unavailable on this device."
        case .unavailable(.modelNotReady):
            return "Chapterize will appear when the local model is ready."
        @unknown default:
            return "Chapterize is unavailable right now."
        }
    }

    func chapterize(title: String, blocks: [ArticleMarkdownSegmenter.Block]) async throws -> [ArticleChapter] {
        guard Self.isAvailable else { throw ArticleChapterizerError.unavailable }

        let batches = makeBatches(from: blocks)
        var chapters: [ArticleChapter] = []

        for batch in batches {
            do {
                chapters.append(contentsOf: try await generateChapters(title: title, blocks: batch, retry: false))
            } catch LanguageModelSession.GenerationError.decodingFailure {
                do {
                    chapters.append(contentsOf: try await generateChapters(title: title, blocks: batch, retry: true))
                } catch LanguageModelSession.GenerationError.decodingFailure {
                    chapters.append(contentsOf: fallbackChapters(from: batch))
                }
            }
        }

        let validated = ArticleChapterValidator.validated(chapters, paragraphCount: blocks.count)
        return validated.isEmpty ? fallbackChapters(from: blocks) : validated
    }

    private func generateChapters(title: String, blocks: [ArticleMarkdownSegmenter.Block], retry: Bool) async throws -> [ArticleChapter] {
        let session = LanguageModelSession(
            model: SystemLanguageModel(useCase: .contentTagging),
            instructions: """
            Segment readable articles into contiguous chapters. \
            Return plain, concise titles and valid paragraph index ranges only. \
            Use the paragraph indices from the prompt exactly.
            """
        )
        let response = try await session.respond(
            to: retry ? retryPrompt(title: title, blocks: blocks) : prompt(title: title, blocks: blocks),
            generating: ChapterResponse.self,
            options: GenerationOptions(temperature: retry ? 0.0 : 0.2, maximumResponseTokens: 900)
        )
        return response.content.chapters.map {
            ArticleChapter(
                title: $0.title,
                startParagraphIndex: $0.startParagraphIndex,
                endParagraphIndex: $0.endParagraphIndex
            )
        }
    }

    private func prompt(title: String, blocks: [ArticleMarkdownSegmenter.Block]) -> String {
        """
        Article title: \(title)

        Create 3 to 8 chapters for the indexed article text below. \
        Each chapter must cover a contiguous range of paragraph indices. \
        The chapters must be ordered and should not overlap.

        \(ArticleMarkdownSegmenter.indexedText(from: blocks))
        """
    }

    private func retryPrompt(title: String, blocks: [ArticleMarkdownSegmenter.Block]) -> String {
        """
        Article: \(title)

        Return 2 to 6 chapters. Use only paragraph indices shown below.
        Every chapter needs:
        - title: short text
        - startParagraphIndex: first included index
        - endParagraphIndex: last included index

        Make ranges ordered, contiguous, and non-overlapping.

        \(ArticleMarkdownSegmenter.indexedText(from: blocks))
        """
    }

    private func makeBatches(from blocks: [ArticleMarkdownSegmenter.Block]) -> [[ArticleMarkdownSegmenter.Block]] {
        let maximumCharacters = 10_000
        var batches: [[ArticleMarkdownSegmenter.Block]] = []
        var current: [ArticleMarkdownSegmenter.Block] = []
        var currentCount = 0

        for block in blocks {
            let size = block.plainText.count + 16
            if !current.isEmpty, currentCount + size > maximumCharacters {
                batches.append(current)
                current = []
                currentCount = 0
            }
            current.append(block)
            currentCount += size
        }

        if !current.isEmpty {
            batches.append(current)
        }

        return batches
    }

    private func fallbackChapters(from blocks: [ArticleMarkdownSegmenter.Block]) -> [ArticleChapter] {
        guard blocks.count > 1 else {
            return [ArticleChapter(title: "Article", startParagraphIndex: 0, endParagraphIndex: max(0, blocks.count - 1))]
        }

        let headingChapters = chaptersFromHeadings(blocks)
        if headingChapters.count > 1 {
            return headingChapters
        }

        let targetCount = min(6, max(2, Int((Double(blocks.count) / 5.0).rounded(.up))))
        let chunkSize = Int((Double(blocks.count) / Double(targetCount)).rounded(.up))
        var chapters: [ArticleChapter] = []
        var start = 0

        while start < blocks.count {
            let end = min(blocks.count - 1, start + chunkSize - 1)
            chapters.append(ArticleChapter(
                title: fallbackTitle(for: blocks[start], index: chapters.count + 1),
                startParagraphIndex: start,
                endParagraphIndex: end
            ))
            start = end + 1
        }

        return chapters
    }

    private func chaptersFromHeadings(_ blocks: [ArticleMarkdownSegmenter.Block]) -> [ArticleChapter] {
        let headingIndices = blocks.indices.filter { index in
            let markdown = blocks[index].markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            return markdown.hasPrefix("#")
        }
        guard !headingIndices.isEmpty else { return [] }

        return headingIndices.enumerated().map { offset, startIndex in
            let nextStart = offset + 1 < headingIndices.count ? headingIndices[offset + 1] : blocks.count
            return ArticleChapter(
                title: headingTitle(from: blocks[startIndex], fallbackIndex: offset + 1),
                startParagraphIndex: startIndex,
                endParagraphIndex: max(startIndex, nextStart - 1)
            )
        }
    }

    private func fallbackTitle(for block: ArticleMarkdownSegmenter.Block, index: Int) -> String {
        let text = block.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "Part \(index)" }
        return String(text.prefix(54)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func headingTitle(from block: ArticleMarkdownSegmenter.Block, fallbackIndex: Int) -> String {
        let title = block.markdown
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Part \(fallbackIndex)" : title
    }

    @Generable
    struct ChapterResponse {
        @Guide(description: "A concise ordered list of article chapters.", .minimumCount(1), .maximumCount(8))
        let chapters: [GeneratedChapter]
    }

    @Generable
    struct GeneratedChapter {
        @Guide(description: "Short chapter title, no numbering.")
        let title: String

        @Guide(description: "The first paragraph index included in this chapter.", .minimum(0))
        let startParagraphIndex: Int

        @Guide(description: "The last paragraph index included in this chapter.", .minimum(0))
        let endParagraphIndex: Int
    }
}
#endif
