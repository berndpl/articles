import Foundation

enum ArticleChapterViewState: Equatable {
    case hidden
    case canGenerate
    case generating
    case error(String)
    case ready([ArticleChapter])

    static func make(
        chapters: [ArticleChapter],
        modelAvailable: Bool,
        isGenerating: Bool,
        errorMessage: String?
    ) -> ArticleChapterViewState {
        if !chapters.isEmpty {
            return .ready(chapters)
        }
        if isGenerating {
            return .generating
        }
        if let errorMessage, !errorMessage.isEmpty {
            return .error(errorMessage)
        }
        return modelAvailable ? .canGenerate : .hidden
    }
}
