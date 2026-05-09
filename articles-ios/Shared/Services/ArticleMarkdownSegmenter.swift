import Foundation

enum ArticleMarkdownSegmenter {
    struct Block: Identifiable, Hashable {
        let id: Int
        let markdown: String

        var plainText: String {
            ArticleMarkdownDocument.plainText(fromMarkdown: markdown)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func blocks(from markdown: String) -> [Block] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        var blocks: [String] = []
        var current: [String] = []
        var inFence = false

        for line in normalized.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
            }

            if trimmed.isEmpty, !inFence {
                appendBlock(current, to: &blocks)
                current.removeAll()
            } else {
                current.append(line)
            }
        }
        appendBlock(current, to: &blocks)

        return blocks.enumerated().map { index, markdown in
            Block(id: index, markdown: markdown)
        }
    }

    static func markdown(from blocks: [Block], startingAt index: Int) -> String {
        blocks
            .filter { $0.id >= index }
            .map(\.markdown)
            .joined(separator: "\n\n")
    }

    static func indexedText(from blocks: [Block]) -> String {
        blocks
            .map { "[\($0.id)] \($0.plainText.isEmpty ? $0.markdown : $0.plainText)" }
            .joined(separator: "\n")
    }

    private static func appendBlock(_ lines: [String], to blocks: inout [String]) {
        let block = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !block.isEmpty {
            blocks.append(block)
        }
    }
}
