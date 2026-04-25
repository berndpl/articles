import Foundation
import Testing

struct ArticleExtractorTests {
    @Test
    func extractsReadableContentFromFixture() throws {
        let url = try #require(URL(string: "https://example.com/articles/sample"))
        let html = try fixture(named: "sample-article")

        let extracted = try ArticleExtractor.extract(fromHTML: html, baseURL: url)

        #expect(extracted.title == "Sample Story")
        #expect(extracted.previewText.contains("This is the lead paragraph"))
        #expect(extracted.bodyHTML.contains("<p>This is the lead paragraph"))
    }

    private func fixture(named name: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testsDirectory.appendingPathComponent("Fixtures/\(name).html")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
