import Foundation

enum ArticleChapterValidator {
    static func validated(
        _ chapters: [ArticleChapter],
        paragraphCount: Int
    ) -> [ArticleChapter] {
        guard paragraphCount > 0 else { return [] }

        var results: [ArticleChapter] = []
        var nextAllowedStart = 0

        for chapter in chapters.sorted(by: { lhs, rhs in
            if lhs.startParagraphIndex == rhs.startParagraphIndex {
                return lhs.endParagraphIndex < rhs.endParagraphIndex
            }
            return lhs.startParagraphIndex < rhs.startParagraphIndex
        }) {
            let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let start = min(max(chapter.startParagraphIndex, 0), paragraphCount - 1)
            let end = min(max(chapter.endParagraphIndex, start), paragraphCount - 1)
            guard end >= nextAllowedStart else { continue }

            let adjustedStart = max(start, nextAllowedStart)
            guard adjustedStart <= end else { continue }

            results.append(
                ArticleChapter(
                    id: chapter.id,
                    title: title,
                    startParagraphIndex: adjustedStart,
                    endParagraphIndex: end
                )
            )
            nextAllowedStart = end + 1
        }

        return results
    }
}
