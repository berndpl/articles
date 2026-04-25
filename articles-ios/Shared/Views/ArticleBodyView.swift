import SwiftUI
import WebKit

struct ArticleBodyView: View {
    let html: String
    @State private var contentHeight: CGFloat = 100

    var body: some View {
        ArticleWebView(html: html, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

private struct ArticleWebView: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    private var styledHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        :root {
            color-scheme: light dark;
        }
        body {
            font-family: -apple-system, sans-serif;
            font-size: 17px;
            line-height: 1.65;
            margin: 0;
            padding: 0;
            word-break: break-word;
            -webkit-text-size-adjust: none;
        }
        p { margin: 0 0 1em; }
        h2 { font-size: 1.2em; margin: 1.4em 0 0.4em; }
        h3 { font-size: 1.05em; margin: 1.2em 0 0.3em; }
        a { color: #007AFF; text-decoration: none; }
        blockquote {
            border-left: 3px solid #ccc;
            margin: 1em 0;
            padding-left: 1em;
            color: #666;
        }
        @media (prefers-color-scheme: dark) {
            blockquote { border-color: #555; color: #999; }
        }
        pre, code {
            font-family: ui-monospace, monospace;
            font-size: 14px;
            background: rgba(128,128,128,0.15);
            padding: 2px 5px;
            border-radius: 4px;
        }
        pre { padding: 12px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ArticleWebView

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                guard let height = result as? CGFloat else { return }
                DispatchQueue.main.async {
                    self.parent.contentHeight = height
                }
            }
        }
    }
}
