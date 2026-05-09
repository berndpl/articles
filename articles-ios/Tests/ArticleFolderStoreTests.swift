import Foundation
import SwiftData
import Testing

@MainActor
struct ArticleFolderStoreTests {
    @Test
    func replacesDuplicateByCanonicalURLAndScansFolder() throws {
        let folder = try temporaryFolder()
        let first = ArticleMarkdownDocument(
            url: "https://example.com/story?utm_source=a",
            canonicalURL: "https://example.com/story",
            title: "First",
            sourceDomain: "example.com",
            markdown: "# First\n\nOld."
        )
        let second = ArticleMarkdownDocument(
            url: "https://example.com/story",
            canonicalURL: "https://example.com/story",
            title: "Second",
            sourceDomain: "example.com",
            markdown: "# Second\n\nNew."
        )

        let firstFile = try ArticleFolderStore.write(first, in: folder)
        let secondFile = try ArticleFolderStore.write(second, in: folder)
        let articles = try ArticleFolderStore.scan(in: folder)

        #expect(firstFile.fileURL == secondFile.fileURL)
        #expect(articles.count == 1)
        #expect(articles.first?.document.title == "Second")
    }

    @Test
    func repositoryIndexesFolderArticle() throws {
        let folder = try temporaryFolder()
        let container = SharedStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let repository = ArticleRepository(context: context)
        let document = ArticleMarkdownDocument(
            url: "https://example.com/story",
            canonicalURL: "https://example.com/story",
            title: "Indexed Story",
            sourceDomain: "example.com",
            chapters: [
                ArticleChapter(title: "Start", startParagraphIndex: 0, endParagraphIndex: 1)
            ],
            markdown: "# Indexed Story\n\nReadable body."
        )
        let folderArticle = try ArticleFolderStore.write(document, in: folder)

        _ = try repository.upsert(folderArticle: folderArticle)

        let articles = try repository.allArticles()
        #expect(articles.count == 1)
        #expect(articles.first?.title == "Indexed Story")
        #expect(articles.first?.fileName == folderArticle.fileURL.lastPathComponent)
        #expect(articles.first?.chapters.first?.title == "Start")
    }

    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
