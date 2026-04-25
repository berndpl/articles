import Foundation
import SwiftSoup

struct ExtractedArticle {
    let title: String
    let bodyHTML: String
    let previewText: String
    let sourceDomain: String
}

enum ArticleExtractionError: LocalizedError {
    case invalidResponse
    case emptyDocument
    case noReadableContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The webpage could not be loaded."
        case .emptyDocument:
            return "The webpage did not contain any readable content."
        case .noReadableContent:
            return "The article extractor could not find enough readable text."
        }
    }
}

enum ArticleExtractor {
    static func extract(from url: URL) async throws -> ExtractedArticle {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<400 ~= httpResponse.statusCode else {
            throw ArticleExtractionError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw ArticleExtractionError.emptyDocument
        }

        return try extract(fromHTML: html, baseURL: url)
    }

    static func extract(fromHTML html: String, baseURL: URL) throws -> ExtractedArticle {
        let document = try SwiftSoup.parse(html, baseURL.absoluteString)
        try removeDiscardedNodes(in: document)

        let candidate = try bestCandidate(in: document)
        let fragment = try sanitize(candidate: candidate)
        let bodyHTML = try fragment.body()?.html().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previewText = try fragment.text()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !previewText.isEmpty else {
            throw ArticleExtractionError.emptyDocument
        }

        guard previewText.count >= 140 || bodyHTML.contains("<p") else {
            throw ArticleExtractionError.noReadableContent
        }

        return ExtractedArticle(
            title: try extractTitle(from: document, fallback: baseURL.host(percentEncoded: false) ?? "Article"),
            bodyHTML: wrapHTML(title: try extractTitle(from: document, fallback: baseURL.host(percentEncoded: false) ?? "Article"), bodyHTML: bodyHTML),
            previewText: String(previewText.prefix(220)),
            sourceDomain: baseURL.host(percentEncoded: false) ?? baseURL.absoluteString
        )
    }

    private static func removeDiscardedNodes(in document: Document) throws {
        let selectors = [
            "script", "style", "svg", "nav", "footer", "header", "aside", "form",
            "button", "input", "noscript", "iframe", ".advertisement", ".ad", ".ads", ".social",
            ".newsletter", ".related", ".recommended", ".comments", ".cookie", ".promo"
        ]
        try document.select(selectors.joined(separator: ", ")).remove()
    }

    private static func bestCandidate(in document: Document) throws -> Element {
        let preferredSelectors = [
            "article",
            "main article",
            "[itemprop=articleBody]",
            ".article-body",
            ".entry-content",
            ".post-content",
            ".story-body",
            ".article-content",
            "main"
        ]

        for selector in preferredSelectors {
            if let element = try document.select(selector).first(), try candidateScore(for: element) > 120 {
                return element
            }
        }

        let candidates = try document.select("article, main, section, div")
        let scored = try candidates
            .map { ($0, try candidateScore(for: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        if let best = scored.first?.0 {
            return best
        }

        if let body = document.body() {
            return body
        }

        throw ArticleExtractionError.noReadableContent
    }

    private static func candidateScore(for element: Element) throws -> Int {
        let text = try element.text()
        let normalizedText = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let textLength = normalizedText.count
        guard textLength > 120 else { return 0 }

        let paragraphCount = try element.select("p").count
        let headingCount = try element.select("h1, h2, h3").count
        let linkTextLength = try element.select("a").array().reduce(0) { partialResult, link in
            partialResult + ((try? link.text().count) ?? 0)
        }

        let linkDensityPenalty = textLength == 0 ? 0 : (linkTextLength * 100 / textLength)
        let classAndID = try element.className() + " " + element.id()
        let lowerClassAndID = classAndID.lowercased()

        var bonus = 0
        if ["article", "content", "story", "entry", "post", "main"].contains(where: lowerClassAndID.contains) {
            bonus += 120
        }
        if ["comment", "footer", "header", "nav", "promo", "share"].contains(where: lowerClassAndID.contains) {
            bonus -= 140
        }

        return textLength + (paragraphCount * 60) + (headingCount * 20) + bonus - (linkDensityPenalty * 8)
    }

    private static func sanitize(candidate: Element) throws -> Document {
        let fragment = try SwiftSoup.parseBodyFragment(candidate.outerHtml())
        let body = fragment.body()
        let selectors = [
            "script", "style", "svg", "nav", "footer", "header", "aside", "form",
            ".advertisement", ".ad", ".ads", ".share", ".social", ".comments", ".cookie"
        ]
        try body?.select(selectors.joined(separator: ", ")).remove()
        try body?.select("img, picture, figure").remove()

        // Remove the first h1 — the app header already shows the title
        if let firstH1 = try body?.select("h1").first() {
            try firstH1.remove()
        }

        return fragment
    }

    private static func extractTitle(from document: Document, fallback: String) throws -> String {
        let selectors = [
            "meta[property=og:title]",
            "meta[name=twitter:title]",
            "article h1",
            "main h1",
            "h1",
            "title"
        ]

        for selector in selectors {
            if let element = try document.select(selector).first() {
                let value: String
                if selector.hasPrefix("meta") {
                    value = try element.attr("content")
                } else {
                    value = try element.text()
                }

                let cleaned = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return fallback
    }

    private static func wrapHTML(title: String, bodyHTML: String) -> String {
        "<article>\(bodyHTML)</article>"
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
