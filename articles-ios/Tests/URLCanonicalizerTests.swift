import Foundation
import Testing

struct URLCanonicalizerTests {
    @Test
    func removesTrackingParametersAndFragments() throws {
        let url = try #require(URL(string: "https://Example.com/story/?utm_source=newsletter&fbclid=123&b=2#a"))
        #expect(URLCanonicalizer.canonicalString(from: url) == "https://example.com/story?b=2")
    }

    @Test
    func dropsDefaultPortsAndTrailingSlash() throws {
        let url = try #require(URL(string: "https://example.com:443/path/"))
        #expect(URLCanonicalizer.canonicalString(from: url) == "https://example.com/path")
    }
}
