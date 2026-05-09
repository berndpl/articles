import Foundation
import Testing

struct ArticleMarkdownDocumentTests {
    @Test
    func parsesLegacyFrontmatterWithOnlyURL() throws {
        let text = """
        ---
        url: https://example.com/story
        ---

        # Legacy Story

        Body text.
        """

        let document = try #require(ArticleMarkdownDocument.parse(text))

        #expect(document.url == "https://example.com/story")
        #expect(document.effectiveCanonicalURL == "https://example.com/story")
        #expect(document.effectiveTitle == "Legacy Story")
        #expect(document.previewText.contains("Body text"))
    }

    @Test
    func serializesExpandedFrontmatter() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-04-27T12:00:00Z"))
        let chapterID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let document = ArticleMarkdownDocument(
            url: "https://example.com/story?utm_source=x",
            canonicalURL: "https://example.com/story",
            title: "Story: With Punctuation",
            sourceDomain: "example.com",
            createdAt: date,
            updatedAt: date,
            chapters: [
                ArticleChapter(
                    id: chapterID,
                    title: "Opening: Moves",
                    startParagraphIndex: 0,
                    endParagraphIndex: 3
                )
            ],
            markdown: "# Story\n\nBody."
        )

        let parsed = try #require(ArticleMarkdownDocument.parse(document.serialized()))

        #expect(parsed.url == document.url)
        #expect(parsed.canonicalURL == document.canonicalURL)
        #expect(parsed.title == document.title)
        #expect(parsed.sourceDomain == document.sourceDomain)
        #expect(parsed.chapters == document.chapters)
        #expect(parsed.markdown == "# Story\n\nBody.")
    }

    @Test
    func createsStableSluggedFilename() {
        #expect(ArticleMarkdownDocument.filename(for: "Hello, Wide World!", date: Date(timeIntervalSince1970: 0)) == "700101-hello-wide-world.md")
    }
}
