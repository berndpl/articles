import Foundation

struct ArticleChapter: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var startParagraphIndex: Int
    var endParagraphIndex: Int

    init(
        id: UUID = UUID(),
        title: String,
        startParagraphIndex: Int,
        endParagraphIndex: Int
    ) {
        self.id = id
        self.title = title
        self.startParagraphIndex = startParagraphIndex
        self.endParagraphIndex = endParagraphIndex
    }
}
