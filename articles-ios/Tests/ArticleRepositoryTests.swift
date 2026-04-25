import Foundation
import SwiftData
import Testing

@MainActor
struct ArticleRepositoryTests {
    @Test
    func upsertReusesExistingArticleForCanonicalURL() throws {
        let container = SharedStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let repository = ArticleRepository(context: context)

        let first = try #require(URL(string: "https://example.com/story?utm_source=a"))
        let second = try #require(URL(string: "https://example.com/story"))

        let articleA = try repository.upsertPendingArticle(for: first)
        let articleB = try repository.upsertPendingArticle(for: second)

        #expect(articleA.persistentModelID == articleB.persistentModelID)
        #expect(try repository.allArticles().count == 1)
    }
}
