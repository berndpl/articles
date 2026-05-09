import Foundation
import SwiftData
import Testing

@MainActor
struct ArticleChapterTests {
    @Test
    func segmentsMarkdownIntoAddressableBlocks() {
        let markdown = """
        # Heading

        First paragraph.

        - One
        - Two

        > Quote

        ```
        let x = 1

        let y = 2
        ```
        """

        let blocks = ArticleMarkdownSegmenter.blocks(from: markdown)

        #expect(blocks.map(\.id) == [0, 1, 2, 3, 4])
        #expect(blocks[0].markdown == "# Heading")
        #expect(blocks[2].markdown.contains("- One"))
        #expect(blocks[4].markdown.contains("let y = 2"))
    }

    @Test
    func validatesAndClampsChapterRanges() {
        let chapters = [
            ArticleChapter(title: "  ", startParagraphIndex: 0, endParagraphIndex: 1),
            ArticleChapter(title: "Intro", startParagraphIndex: -2, endParagraphIndex: 1),
            ArticleChapter(title: "Overlap", startParagraphIndex: 1, endParagraphIndex: 2),
            ArticleChapter(title: "End", startParagraphIndex: 9, endParagraphIndex: 12)
        ]

        let validated = ArticleChapterValidator.validated(chapters, paragraphCount: 5)

        #expect(validated.count == 3)
        #expect(validated[0].title == "Intro")
        #expect(validated[0].startParagraphIndex == 0)
        #expect(validated[0].endParagraphIndex == 1)
        #expect(validated[1].startParagraphIndex == 2)
        #expect(validated[2].startParagraphIndex == 4)
        #expect(validated[2].endParagraphIndex == 4)
    }

    @Test
    func articleEncodesAndDecodesCachedChapters() {
        let article = Article(
            sourceURL: "https://example.com",
            canonicalURL: "https://example.com",
            sourceDomain: "example.com"
        )
        let chapters = [
            ArticleChapter(title: "Start", startParagraphIndex: 0, endParagraphIndex: 2),
            ArticleChapter(title: "Finish", startParagraphIndex: 3, endParagraphIndex: 5)
        ]

        article.chapters = chapters

        #expect(article.chapters == chapters)
        #expect(article.chaptersData != nil)
    }

    @Test
    func speechTextCanStartAtParagraphIndex() {
        let markdown = """
        # Title

        First paragraph.

        Second paragraph with [link](https://example.com).
        """

        let text = ArticleSpeechSynthesizer.readableText(from: markdown, startingAtParagraphIndex: 2)

        #expect(!text.contains("First paragraph"))
        #expect(text.contains("Second paragraph with link"))
    }

    @Test
    func chapterViewStateReflectsReaderActions() {
        let chapters = [ArticleChapter(title: "Intro", startParagraphIndex: 0, endParagraphIndex: 1)]

        #expect(ArticleChapterViewState.make(chapters: [], modelAvailable: false, isGenerating: false, errorMessage: nil) == .hidden)
        #expect(ArticleChapterViewState.make(chapters: [], modelAvailable: true, isGenerating: false, errorMessage: nil) == .canGenerate)
        #expect(ArticleChapterViewState.make(chapters: [], modelAvailable: true, isGenerating: true, errorMessage: nil) == .generating)
        #expect(ArticleChapterViewState.make(chapters: [], modelAvailable: true, isGenerating: false, errorMessage: "Nope") == .error("Nope"))
        #expect(ArticleChapterViewState.make(chapters: chapters, modelAvailable: false, isGenerating: false, errorMessage: nil) == .ready(chapters))
    }
}
