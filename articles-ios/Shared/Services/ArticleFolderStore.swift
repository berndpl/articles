import Foundation

enum ArticleFolderError: LocalizedError {
    case folderNotSelected
    case bookmarkInvalid

    var errorDescription: String? {
        switch self {
        case .folderNotSelected:
            return "Open Articles and choose a shared folder before saving from the share sheet."
        case .bookmarkInvalid:
            return "The selected Articles folder could not be opened. Choose it again in Settings."
        }
    }
}

struct FolderArticle {
    let document: ArticleMarkdownDocument
    let fileURL: URL
    let modifiedAt: Date?
}

enum ArticleFolderStore {
    static let bookmarkKey = "ArticleFolderBookmark"

    static var hasSelectedFolder: Bool {
        guard userDefaults.data(forKey: bookmarkKey) != nil else { return false }
        return (try? withFolderURL { folderURL in
            _ = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        }) != nil
    }

    static func displayPath() -> String? {
        guard let url = try? resolveFolderURL().url else { return nil }
        return url.path(percentEncoded: false)
    }

    static func setFolder(_ url: URL) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        userDefaults.set(bookmark, forKey: bookmarkKey)
        do {
            try validateSelectedFolderAccess()
        } catch {
            clearFolder()
            throw error
        }
    }

    static func clearFolder() {
        userDefaults.removeObject(forKey: bookmarkKey)
    }

    static func scan() throws -> [FolderArticle] {
        try withFolderURL { folderURL in
            try scan(in: folderURL)
        }
    }

    static func validateSelectedFolderAccess() throws {
        try withFolderURL { folderURL in
            _ = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let probeURL = folderURL.appendingPathComponent(".articles-folder-access-check")
            try "ok".write(to: probeURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: probeURL)
        }
    }

    static func scan(in folderURL: URL) throws -> [FolderArticle] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      let document = ArticleMarkdownDocument.parse(text)
                else { return nil }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                return FolderArticle(document: document, fileURL: url, modifiedAt: values?.contentModificationDate)
            }
            .sorted { lhs, rhs in
                (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
            }
    }

    @discardableResult
    static func write(_ document: ArticleMarkdownDocument, replacing fileName: String? = nil) throws -> FolderArticle {
        try withFolderURL { folderURL in
            try write(document, in: folderURL, replacing: fileName)
        }
    }

    @discardableResult
    static func write(_ document: ArticleMarkdownDocument, in folderURL: URL, replacing fileName: String? = nil) throws -> FolderArticle {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let existingURL = try findDuplicateURL(for: document, in: folderURL, preserving: fileName)
        let targetURL = existingURL ?? uniqueURL(
            in: folderURL,
            preferredName: fileName ?? ArticleMarkdownDocument.filename(for: document.effectiveTitle, date: document.createdAt ?? .now)
        )
        try document.serialized().write(to: targetURL, atomically: true, encoding: .utf8)
        let values = try? targetURL.resourceValues(forKeys: [.contentModificationDateKey])
        return FolderArticle(document: document, fileURL: targetURL, modifiedAt: values?.contentModificationDate)
    }

    static func delete(fileName: String?) throws {
        guard let fileName, !fileName.isEmpty else { return }
        try withFolderURL { folderURL in
            let url = folderURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    static func filename(for url: URL) -> String {
        url.lastPathComponent
    }

    private static func findDuplicateURL(for document: ArticleMarkdownDocument, in folderURL: URL, preserving fileName: String?) throws -> URL? {
        if let fileName, !fileName.isEmpty {
            let url = folderURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        let urls = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for url in urls where url.pathExtension.lowercased() == "md" {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let existing = ArticleMarkdownDocument.parse(text)
            else { continue }
            if existing.effectiveCanonicalURL == document.effectiveCanonicalURL || existing.url == document.url {
                return url
            }
        }
        return nil
    }

    private static func uniqueURL(in folderURL: URL, preferredName: String) -> URL {
        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension.isEmpty ? "md" : (preferredName as NSString).pathExtension
        var candidate = folderURL.appendingPathComponent("\(base).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(base)-\(index).\(ext)")
            index += 1
        }
        return candidate
    }

    private static func withFolderURL<T>(_ body: (URL) throws -> T) throws -> T {
        let resolution = try resolveFolderURL()
        let didStart = resolution.url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                resolution.url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(resolution.url)
    }

    private static func resolveFolderURL() throws -> (url: URL, stale: Bool) {
        guard let data = userDefaults.data(forKey: bookmarkKey) else {
            throw ArticleFolderError.folderNotSelected
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            try setFolder(url)
        }
        return (url, stale)
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConfiguration.identifier) ?? .standard
    }
}
