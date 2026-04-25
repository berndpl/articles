import Foundation

enum URLCanonicalizer {
    private static let strippedQueryItems = Set([
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "mc_cid", "mc_eid", "igshid"
    ])

    static func canonicalize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil

        if components.path.isEmpty {
            components.path = "/"
        }

        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        if components.port == 80 && components.scheme == "http" {
            components.port = nil
        } else if components.port == 443 && components.scheme == "https" {
            components.port = nil
        }

        if let queryItems = components.queryItems, !queryItems.isEmpty {
            let filtered = queryItems.filter { !strippedQueryItems.contains($0.name.lowercased()) }
            components.queryItems = filtered.isEmpty ? nil : filtered.sorted { $0.name < $1.name }
        }

        return components.url ?? url
    }

    static func canonicalString(from url: URL) -> String {
        canonicalize(url).absoluteString
    }
}
