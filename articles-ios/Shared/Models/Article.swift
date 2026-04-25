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
        errorMessage: String? = nil
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
}

extension Article {
    static var previewReady: Article {
        Article(
            sourceURL: "https://www.example.com/story",
            canonicalURL: "https://www.example.com/story",
            title: "A Saved Article",
            sourceDomain: "example.com",
            bodyContent: "<h1>A Saved Article</h1><p>This is a preview article rendered from stored HTML.</p>",
            previewText: "This is a preview article rendered from stored HTML.",
            status: .ready
        )
    }
}
