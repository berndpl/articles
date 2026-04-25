import Foundation
import SwiftData

@MainActor
enum ArticleIngestionService {
    @discardableResult
    static func ingest(url: URL, in context: ModelContext) async -> Article {
        let repository = ArticleRepository(context: context)

        do {
            let article = try repository.upsertPendingArticle(for: url)
            try repository.markExtracting(article)

            let extracted = try await ArticleExtractor.extract(from: url)
            try repository.markReady(article, extracted: extracted)
            return article
        } catch {
            let article: Article
            if let existing = try? repository.upsertPendingArticle(for: url) {
                article = existing
            } else {
                article = Article(
                    sourceURL: url.absoluteString,
                    canonicalURL: URLCanonicalizer.canonicalString(from: url),
                    sourceDomain: url.host(percentEncoded: false) ?? url.absoluteString,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
                context.insert(article)
            }

            try? repository.markFailed(article, message: error.localizedDescription)
            return article
        }
    }

    static func retry(_ article: Article, in context: ModelContext) async {
        guard let url = URL(string: article.sourceURL) else {
            let repository = ArticleRepository(context: context)
            try? repository.markFailed(article, message: "The original URL is invalid.")
            return
        }
        _ = await ingest(url: url, in: context)
    }

    static func resumeIncompleteArticles(in context: ModelContext) async {
        let repository = ArticleRepository(context: context)
        let articles = (try? repository.incompleteArticles()) ?? []

        for article in articles {
            guard let url = URL(string: article.sourceURL) else {
                try? repository.markFailed(article, message: "The original URL is invalid.")
                continue
            }
            _ = await ingest(url: url, in: context)
        }
    }
}
