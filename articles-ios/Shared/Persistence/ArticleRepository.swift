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

    func article(fileName: String) throws -> Article? {
        var descriptor = FetchDescriptor<Article>(
            predicate: #Predicate<Article> { article in
                article.fileName == fileName
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
        let markdown = HTMLToMarkdownConverter.convert(extracted.bodyHTML, title: extracted.title)
        let now = Date()
        let shouldKeepChapters = article.bodyContent == markdown
        let document = ArticleMarkdownDocument(
            url: article.sourceURL,
            canonicalURL: article.canonicalURL,
            title: extracted.title,
            sourceDomain: extracted.sourceDomain,
            createdAt: article.createdAt,
            updatedAt: now,
            chapters: shouldKeepChapters ? article.chapters : [],
            markdown: markdown
        )
        let folderArticle = try ArticleFolderStore.write(document, replacing: article.fileName)

        article.title = extracted.title
        article.sourceDomain = extracted.sourceDomain
        if article.bodyContent != markdown {
            article.chapters = []
        }
        article.bodyContent = markdown
        article.previewText = document.previewText.isEmpty ? extracted.previewText : document.previewText
        article.updatedAt = now
        article.status = .ready
        article.errorMessage = nil
        article.fileName = ArticleFolderStore.filename(for: folderArticle.fileURL)
        article.fileModifiedAt = folderArticle.modifiedAt
        try context.save()
    }

    @discardableResult
    func upsert(folderArticle: FolderArticle) throws -> Article {
        let document = folderArticle.document
        let fileName = ArticleFolderStore.filename(for: folderArticle.fileURL)
        let canonicalURL = document.effectiveCanonicalURL
        let sourceURL = document.url
        let createdAt = document.createdAt ?? folderArticle.modifiedAt ?? .now
        let updatedAt = document.updatedAt ?? folderArticle.modifiedAt ?? createdAt
        let domain = document.sourceDomain
            ?? URL(string: sourceURL)?.host(percentEncoded: false)
            ?? sourceURL

        let existing = try article(fileName: fileName) ?? article(for: canonicalURL)
        let article = existing ?? Article(
            sourceURL: sourceURL,
            canonicalURL: canonicalURL,
            sourceDomain: domain,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        if existing == nil {
            context.insert(article)
        }

        article.sourceURL = sourceURL
        article.canonicalURL = canonicalURL
        article.title = document.effectiveTitle
        article.sourceDomain = domain
        if article.bodyContent != document.markdown && document.chapters.isEmpty {
            article.chapters = []
        }
        article.bodyContent = document.markdown
        if !document.chapters.isEmpty {
            article.chapters = document.chapters
        }
        article.previewText = document.previewText
        article.createdAt = createdAt
        article.updatedAt = updatedAt
        article.status = .ready
        article.errorMessage = nil
        article.fileName = fileName
        article.fileModifiedAt = folderArticle.modifiedAt
        try context.save()
        return article
    }

    func exportReadyArticlesToFolder() throws {
        for article in try allArticles() where article.status == .ready {
            let markdown = article.bodyContent.contains("<")
                ? HTMLToMarkdownConverter.convert(article.bodyContent, title: article.displayTitle)
                : article.bodyContent
            let shouldKeepChapters = article.bodyContent == markdown
            let document = ArticleMarkdownDocument(
                url: article.sourceURL,
                canonicalURL: article.canonicalURL,
                title: article.displayTitle,
                sourceDomain: article.sourceDomain,
                createdAt: article.createdAt,
                updatedAt: article.updatedAt,
                chapters: shouldKeepChapters ? article.chapters : [],
                markdown: markdown
            )
            let folderArticle = try ArticleFolderStore.write(document, replacing: article.fileName)
            if article.bodyContent != markdown {
                article.chapters = []
            }
            article.bodyContent = markdown
            article.fileName = ArticleFolderStore.filename(for: folderArticle.fileURL)
            article.fileModifiedAt = folderArticle.modifiedAt
        }
        try context.save()
    }

    func indexFolderArticles() throws {
        for folderArticle in try ArticleFolderStore.scan() {
            _ = try upsert(folderArticle: folderArticle)
        }
    }

    func deleteArticleAndFile(_ article: Article) throws {
        try ArticleFolderStore.delete(fileName: article.fileName)
        context.delete(article)
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
