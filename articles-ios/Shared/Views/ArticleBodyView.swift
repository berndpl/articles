import SwiftUI

struct ArticleBodyView: View {
    let blocks: [ArticleMarkdownSegmenter.Block]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                ArticleMarkdownBlockView(markdown: block.markdown)
                    .id(block.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArticleMarkdownBlockView: View {
    let markdown: String

    var body: some View {
        Text(attributedMarkdown)
            .font(.body)
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedMarkdown: AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
