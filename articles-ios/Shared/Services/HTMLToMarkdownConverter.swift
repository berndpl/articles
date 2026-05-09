import Foundation
import SwiftSoup

enum HTMLToMarkdownConverter {
    static func convert(_ html: String, title: String? = nil) -> String {
        do {
            let document = try SwiftSoup.parseBodyFragment(html)
            var lines: [String] = []

            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("# \(title.trimmingCharacters(in: .whitespacesAndNewlines))")
                lines.append("")
            }

            if let body = document.body() {
                for child in body.getChildNodes() {
                    appendMarkdown(for: child, into: &lines, listPrefix: nil)
                }
            }

            return normalize(lines.joined(separator: "\n"))
        } catch {
            return html
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func appendMarkdown(for node: Node, into lines: inout [String], listPrefix: String?) {
        if let textNode = node as? TextNode {
            let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                lines.append(text)
                lines.append("")
            }
            return
        }

        guard let element = node as? Element else { return }
        let tag = element.tagName().lowercased()

        switch tag {
        case "article", "main", "section", "div", "body":
            for child in element.getChildNodes() {
                appendMarkdown(for: child, into: &lines, listPrefix: listPrefix)
            }
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(tag.dropFirst())) ?? 2
            if let text = try? inlineMarkdown(for: element), !text.isEmpty {
                lines.append("\(String(repeating: "#", count: level)) \(text)")
                lines.append("")
            }
        case "p":
            if let text = try? inlineMarkdown(for: element), !text.isEmpty {
                lines.append(text)
                lines.append("")
            }
        case "blockquote":
            if let text = try? inlineMarkdown(for: element), !text.isEmpty {
                for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                    lines.append("> \(line)")
                }
                lines.append("")
            }
        case "pre":
            let code = ((try? element.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty {
                lines.append("```")
                lines.append(code)
                lines.append("```")
                lines.append("")
            }
        case "ul":
            for child in element.children() {
                appendMarkdown(for: child, into: &lines, listPrefix: "- ")
            }
            lines.append("")
        case "ol":
            for (index, child) in element.children().array().enumerated() {
                appendMarkdown(for: child, into: &lines, listPrefix: "\(index + 1). ")
            }
            lines.append("")
        case "li":
            if let text = try? inlineMarkdown(for: element), !text.isEmpty {
                lines.append("\(listPrefix ?? "- ")\(text)")
            }
        case "br":
            lines.append("")
        default:
            if let text = try? inlineMarkdown(for: element), !text.isEmpty {
                lines.append(text)
                lines.append("")
            }
        }
    }

    private static func inlineMarkdown(for element: Element) throws -> String {
        var parts: [String] = []
        for node in element.getChildNodes() {
            parts.append(try inlineMarkdown(for: node))
        }
        return parts.joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineMarkdown(for node: Node) throws -> String {
        if let text = node as? TextNode {
            return text.text()
        }

        guard let element = node as? Element else { return "" }
        let text = try inlineMarkdown(for: element)
        switch element.tagName().lowercased() {
        case "a":
            let href = try element.attr("href")
            return href.isEmpty ? text : "[\(text)](\(href))"
        case "strong", "b":
            return text.isEmpty ? "" : "**\(text)**"
        case "em", "i":
            return text.isEmpty ? "" : "*\(text)*"
        case "code":
            return text.isEmpty ? "" : "`\(text)`"
        case "br":
            return "\n"
        default:
            return text
        }
    }

    private static func normalize(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
