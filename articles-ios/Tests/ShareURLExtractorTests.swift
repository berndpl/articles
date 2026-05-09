import Foundation
import Testing

struct ShareURLExtractorTests {
    @Test
    func acceptsURLShareItems() {
        let item = URL(string: "https://example.com/story")! as NSURL

        let url = ShareURLExtractor.url(from: item)

        #expect(url?.absoluteString == "https://example.com/story")
    }

    @Test
    func extractsFirstHTTPURLFromText() {
        let url = ShareURLExtractor.url(fromPlainText: "Read this: https://example.com/story?x=1")

        #expect(url?.absoluteString == "https://example.com/story?x=1")
    }

    @Test
    func extractsURLFromSafariPropertyList() {
        let propertyList: [AnyHashable: Any] = [
            "NSExtensionJavaScriptPreprocessingResultsKey": [
                "URL": "https://example.com/safari"
            ]
        ]

        let url = ShareURLExtractor.url(fromPropertyList: propertyList)

        #expect(url?.absoluteString == "https://example.com/safari")
    }

    @Test
    func extractsURLFromHTMLPayload() {
        let html = """
        <html><head><link rel="canonical" href="https://example.com/html"></head><body></body></html>
        """

        let url = ShareURLExtractor.url(from: html)

        #expect(url?.absoluteString == "https://example.com/html")
    }
}
