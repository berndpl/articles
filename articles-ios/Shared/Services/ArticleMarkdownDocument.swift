import Foundation

struct ArticleMarkdownDocument: Equatable {
    var url: String
    var canonicalURL: String?
    var title: String?
    var sourceDomain: String?
    var createdAt: Date?
    var updatedAt: Date?
    var chapters: [ArticleChapter]
    var markdown: String

    var effectiveCanonicalURL: String {
        canonicalURL ?? url
    }

    var effectiveTitle: String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return Self.title(fromMarkdown: markdown) ?? sourceDomain ?? url
    }

    var previewText: String {
        Self.plainText(fromMarkdown: markdown)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefixString(maxLength: 220)
    }

    init(
        url: String,
        canonicalURL: String? = nil,
        title: String? = nil,
        sourceDomain: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        chapters: [ArticleChapter] = [],
        markdown: String
    ) {
        self.url = url
        self.canonicalURL = canonicalURL
        self.title = title
        self.sourceDomain = sourceDomain
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chapters = chapters
        self.markdown = markdown
    }

    static func parse(_ text: String) -> ArticleMarkdownDocument? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n"),
              let endRange = normalized.range(of: "\n---\n", range: normalized.index(normalized.startIndex, offsetBy: 4)..<normalized.endIndex)
        else { return nil }

        let frontmatter = String(normalized[normalized.index(normalized.startIndex, offsetBy: 4)..<endRange.lowerBound])
        let markdownStart = endRange.upperBound
        let markdown = String(normalized[markdownStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = parseFrontmatter(frontmatter)

        guard let url = fields["url"], !url.isEmpty else { return nil }

        return ArticleMarkdownDocument(
            url: url,
            canonicalURL: fields["canonical_url"],
            title: fields["title"],
            sourceDomain: fields["source_domain"],
            createdAt: parseDate(fields["created_at"]),
            updatedAt: parseDate(fields["updated_at"]),
            chapters: parseChapters(frontmatter),
            markdown: markdown
        )
    }

    func serialized() -> String {
        var lines: [String] = ["---"]
        lines.append("url: \(Self.escapeYAML(url))")
        if let canonicalURL, !canonicalURL.isEmpty {
            lines.append("canonical_url: \(Self.escapeYAML(canonicalURL))")
        }
        if let title, !title.isEmpty {
            lines.append("title: \(Self.escapeYAML(title))")
        }
        if let sourceDomain, !sourceDomain.isEmpty {
            lines.append("source_domain: \(Self.escapeYAML(sourceDomain))")
        }
        if let createdAt {
            lines.append("created_at: \(Self.isoFormatter.string(from: createdAt))")
        }
        if let updatedAt {
            lines.append("updated_at: \(Self.isoFormatter.string(from: updatedAt))")
        }
        if !chapters.isEmpty {
            lines.append("chapters:")
            for chapter in chapters {
                lines.append("  - id: \(chapter.id.uuidString)")
                lines.append("    title: \(Self.escapeYAML(chapter.title))")
                lines.append("    start_paragraph_index: \(chapter.startParagraphIndex)")
                lines.append("    end_paragraph_index: \(chapter.endParagraphIndex)")
            }
        }
        lines.append("---")
        lines.append("")
        lines.append(markdown.trimmingCharacters(in: .whitespacesAndNewlines))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    static func filename(for title: String, date: Date = .now) -> String {
        let prefix = fileDateFormatter.string(from: date)
        let slug = slugify(title)
        return "\(prefix)-\(slug.isEmpty ? "untitled" : slug).md"
    }

    static func slugify(_ value: String) -> String {
        let lower = value.lowercased()
        let allowed = lower.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " " || scalar == "-" ? Character(scalar) : "-"
        }
        let raw = String(allowed)
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(collapsed.prefix(60))
    }

    static func plainText(fromMarkdown markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "^---[\\s\\S]*?---", with: "", options: .regularExpression)
            .replacingOccurrences(of: "`{1,3}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^\\)]*\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]*\\)", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: [.regularExpression, .anchored])
            .replacingOccurrences(of: "[*_>#-]", with: "", options: .regularExpression)
    }

    static func title(fromMarkdown markdown: String) -> String? {
        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func parseFrontmatter(_ frontmatter: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in frontmatter.components(separatedBy: .newlines) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                continue
            }
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            value = unescapeYAML(value)
            fields[key] = value
        }
        return fields
    }

    private static func parseChapters(_ frontmatter: String) -> [ArticleChapter] {
        var chapters: [ArticleChapter] = []
        var current: [String: String] = [:]
        var isReadingChapters = false

        func appendCurrent() {
            guard !current.isEmpty else { return }
            let title = current["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let start = Int(current["start_paragraph_index"] ?? current["startParagraphIndex"] ?? "")
            let end = Int(current["end_paragraph_index"] ?? current["endParagraphIndex"] ?? "")
            guard !title.isEmpty, let start, let end else {
                current.removeAll()
                return
            }
            let id = current["id"].flatMap(UUID.init(uuidString:)) ?? UUID()
            chapters.append(ArticleChapter(id: id, title: title, startParagraphIndex: start, endParagraphIndex: end))
            current.removeAll()
        }

        for line in frontmatter.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "chapters:" {
                isReadingChapters = true
                continue
            }
            guard isReadingChapters else { continue }
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                break
            }
            if trimmed.hasPrefix("- ") {
                appendCurrent()
                parseChapterField(String(trimmed.dropFirst(2)), into: &current)
            } else {
                parseChapterField(trimmed, into: &current)
            }
        }
        appendCurrent()
        return chapters
    }

    private static func parseChapterField(_ line: String, into current: inout [String: String]) {
        guard let separator = line.firstIndex(of: ":") else { return }
        let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        current[key] = unescapeYAML(value)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return isoFormatter.date(from: value)
    }

    private static func escapeYAML(_ value: String) -> String {
        if value.range(of: #"[:#\n"]"#, options: .regularExpression) == nil {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private static func unescapeYAML(_ value: String) -> String {
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            return String(value.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        return value
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyMMdd"
        return formatter
    }()
}

private extension String {
    func prefixString(maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}
