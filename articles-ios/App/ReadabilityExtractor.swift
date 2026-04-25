import Foundation
import WebKit

@MainActor
enum ReadabilityExtractor {
    static func extract(from url: URL) async throws -> ExtractedArticle {
        return try await withCheckedThrowingContinuation { continuation in
            let extractor = ReadabilityWebExtractor(url: url, continuation: continuation)
            extractor.start()
            // Keep alive until done
            objc_setAssociatedObject(extractor, &AssociatedKeys.extractor, extractor, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

private enum AssociatedKeys { static var extractor: UInt8 = 0 }

@MainActor
private final class ReadabilityWebExtractor: NSObject, WKNavigationDelegate {
    private let url: URL
    private let continuation: CheckedContinuation<ExtractedArticle, Error>
    private var webView: WKWebView?
    private var finished = false

    init(url: URL, continuation: CheckedContinuation<ExtractedArticle, Error>) {
        self.url = url
        self.continuation = continuation
    }

    func start() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        wv.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !finished else { return }
        let js = ReadabilityJS.source + """
        ;(function() {
            try {
                var article = new Readability(document.cloneNode(true)).parse();
                if (!article) return JSON.stringify({error: "Readability returned null"});
                return JSON.stringify({
                    title: article.title || "",
                    content: article.content || "",
                    excerpt: article.excerpt || "",
                    siteName: article.siteName || ""
                });
            } catch(e) {
                return JSON.stringify({error: e.message});
            }
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self, !self.finished else { return }
            self.finished = true
            self.webView = nil
            objc_setAssociatedObject(self, &AssociatedKeys.extractor, nil, .OBJC_ASSOCIATION_RETAIN)

            if let error {
                self.continuation.resume(throwing: error)
                return
            }

            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            else {
                self.continuation.resume(throwing: ArticleExtractionError.invalidResponse)
                return
            }

            if let errorMsg = json["error"] {
                self.continuation.resume(throwing: ArticleExtractionError.noReadableContent)
                _ = errorMsg
                return
            }

            let title = json["title"] ?? self.url.host() ?? "Article"
            let content = json["content"] ?? ""
            let excerpt = json["excerpt"] ?? ""
            let domain = self.url.host(percentEncoded: false) ?? self.url.absoluteString

            guard !content.isEmpty else {
                self.continuation.resume(throwing: ArticleExtractionError.noReadableContent)
                return
            }

            self.continuation.resume(returning: ExtractedArticle(
                title: title,
                bodyHTML: "<article>\(content)</article>",
                previewText: String(excerpt.prefix(220)),
                sourceDomain: domain
            ))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !finished else { return }
        finished = true
        self.webView = nil
        continuation.resume(throwing: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !finished else { return }
        finished = true
        self.webView = nil
        continuation.resume(throwing: error)
    }
}
