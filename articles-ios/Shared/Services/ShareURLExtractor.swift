import Foundation
import UniformTypeIdentifiers

enum ShareURLExtractor {
    static func extractURL(from extensionContext: NSExtensionContext?) async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        return await extractURL(from: items)
    }

    static func extractURL(from items: [NSExtensionItem]) async -> URL? {
        for item in items {
            if let url = url(from: item.attributedContentText) {
                return url
            }

            if let url = url(from: item.attributedTitle) {
                return url
            }

            if let url = url(fromPropertyList: item.userInfo) {
                return url
            }

            for provider in item.attachments ?? [] {
                if let url = await loadURL(from: provider) {
                    return url
                }
            }
        }
        return nil
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        for typeIdentifier in preferredTypeIdentifiers {
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier),
                  let item = try? await provider.loadItem(forTypeIdentifier: typeIdentifier) else {
                continue
            }

            if let url = url(from: item) {
                return url
            }
        }

        for typeIdentifier in provider.registeredTypeIdentifiers {
            guard let item = try? await provider.loadItem(forTypeIdentifier: typeIdentifier) else {
                continue
            }

            if let url = url(from: item) {
                return url
            }
        }

        return nil
    }

    private static var preferredTypeIdentifiers: [String] {
        [
            UTType.url.identifier,
            UTType.plainText.identifier,
            UTType.text.identifier,
            UTType.html.identifier,
            UTType.propertyList.identifier,
            "public.url",
            "public.file-url",
            "public.utf8-plain-text",
            "public.rtf",
            "com.apple.webarchive"
        ]
    }

    static func url(from item: Any?) -> URL? {
        if let url = item as? URL {
            return url.httpURL
        }

        if let url = item as? NSURL {
            return (url as URL).httpURL
        }

        if let string = item as? String {
            return url(fromPlainText: string)
        }

        if let string = item as? NSString {
            return url(fromPlainText: string as String)
        }

        if let attributedString = item as? NSAttributedString {
            return url(fromPlainText: attributedString.string)
        }

        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) {
            return url(fromPlainText: string)
        }

        if let propertyList = item as? [AnyHashable: Any] {
            return url(fromPropertyList: propertyList)
        }

        if let array = item as? [Any] {
            return array.lazy.compactMap { url(from: $0) }.first
        }

        return nil
    }

    static func url(fromPropertyList propertyList: Any?) -> URL? {
        guard let dictionary = propertyList as? [AnyHashable: Any] else { return nil }

        let preferredKeys = [
            "URL",
            "url",
            "WebURL",
            "webURL",
            "pageURL",
            "NSExtensionJavaScriptPreprocessingResultsKey"
        ]

        for key in preferredKeys {
            if let value = dictionary[key],
               let url = url(fromPropertyListValue: value) {
                return url
            }
        }

        for value in dictionary.values {
            if let url = url(fromPropertyListValue: value) {
                return url
            }
        }

        return nil
    }

    private static func url(fromPropertyListValue value: Any) -> URL? {
        if let dictionary = value as? [AnyHashable: Any] {
            return url(fromPropertyList: dictionary)
        }

        if let array = value as? [Any] {
            return array.lazy.compactMap { url(fromPropertyListValue: $0) }.first
        }

        return url(from: value)
    }

    static func url(fromPlainText string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed)?.httpURL {
            return url
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            return detector
                .matches(in: trimmed, range: range)
                .compactMap(\.url)
                .compactMap(\.httpURL)
                .first
        }

        return nil
    }
}

private extension URL {
    var httpURL: URL? {
        guard scheme == "http" || scheme == "https" else { return nil }
        return self
    }
}
