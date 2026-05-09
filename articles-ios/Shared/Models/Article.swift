import Foundation
import SwiftData

enum ArticleStatus: String, Codable, CaseIterable {
    case pending
    case extracting
    case ready
    case failed
}

@Model
final class Article {
    var id: UUID
    var sourceURL: String
    var canonicalURL: String
    var title: String
    var sourceDomain: String
    var bodyContent: String
    var previewText: String
    var createdAt: Date
    var updatedAt: Date
    var status: ArticleStatus
    var errorMessage: String?
    var fileName: String?
    var fileModifiedAt: Date?
    var chaptersData: Data?

    init(
        id: UUID = UUID(),
        sourceURL: String,
        canonicalURL: String,
        title: String = "",
        sourceDomain: String,
        bodyContent: String = "",
        previewText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: ArticleStatus = .pending,
        errorMessage: String? = nil,
        fileName: String? = nil,
        fileModifiedAt: Date? = nil,
        chaptersData: Data? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.canonicalURL = canonicalURL
        self.title = title
        self.sourceDomain = sourceDomain
        self.bodyContent = bodyContent
        self.previewText = previewText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.errorMessage = errorMessage
        self.fileName = fileName
        self.fileModifiedAt = fileModifiedAt
        self.chaptersData = chaptersData
    }
}

extension Article {
    var sourceURLValue: URL {
        URL(string: sourceURL) ?? URL(string: "https://example.com")!
    }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return sourceDomain
    }

    var statusDescription: String {
        switch status {
        case .pending:
            return "Waiting to process"
        case .extracting:
            return "Extracting article"
        case .ready:
            return previewText
        case .failed:
            return errorMessage ?? "Couldn’t extract article"
        }
    }

    var canRetry: Bool {
        status == .failed
    }

    var chapters: [ArticleChapter] {
        get {
            guard let chaptersData else { return [] }
            return (try? JSONDecoder().decode([ArticleChapter].self, from: chaptersData)) ?? []
        }
        set {
            chaptersData = try? JSONEncoder().encode(newValue)
        }
    }
}

extension Article {
    static var previewReady: Article {
        Article(
            sourceURL: "https://www.example.com/story",
            canonicalURL: "https://www.example.com/story",
            title: "A Saved Article",
            sourceDomain: "example.com",
            bodyContent: "# A Saved Article\n\nThis is a preview article rendered from stored markdown.",
            previewText: "This is a preview article rendered from stored markdown.",
            status: .ready
        )
    }
}
