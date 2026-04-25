import Foundation
import SwiftData

@MainActor
struct ArticleRepository {
    let context: ModelContext

    func allArticles() throws -> [Article] {
        var descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 200
        return try context.fetch(descriptor)
    }

    func article(for canonicalURL: String) throws -> Article? {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { article in
                article.canonicalURL == canonicalURL
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func upsertPendingArticle(for url: URL) throws -> Article {
        let canonicalURL = URLCanonicalizer.canonicalString(from: url)
        let now = Date()

        if let existing = try article(for: canonicalURL) {
            existing.sourceURL = url.absoluteString
            existing.sourceDomain = url.host(percentEncoded: false) ?? existing.sourceDomain
            existing.updatedAt = now
            existing.status = .pending
            existing.errorMessage = nil
            try context.save()
            return existing
        }

        let article = Article(
            sourceURL: url.absoluteString,
            canonicalURL: canonicalURL,
            sourceDomain: url.host(percentEncoded: false) ?? url.absoluteString,
            createdAt: now,
            updatedAt: now,
            status: .pending
        )
        context.insert(article)
        try context.save()
        return article
    }

    func markExtracting(_ article: Article) throws {
        article.status = .extracting
        article.updatedAt = .now
        article.errorMessage = nil
        try context.save()
    }

    func markReady(_ article: Article, extracted: ExtractedArticle) throws {
        article.title = extracted.title
        article.sourceDomain = extracted.sourceDomain
        article.bodyContent = extracted.bodyHTML
        article.previewText = extracted.previewText
        article.updatedAt = .now
        article.status = .ready
        article.errorMessage = nil
        try context.save()
    }

    func markFailed(_ article: Article, message: String) throws {
        article.status = .failed
        article.errorMessage = message
        article.updatedAt = .now
        try context.save()
    }

    func incompleteArticles() throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor).filter { article in
            article.status == .pending || article.status == .extracting
        }
    }
}
