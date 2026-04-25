import SwiftUI

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(article.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                Text(article.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(article.sourceDomain)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: article.status.iconName)
                    .foregroundStyle(article.status.tintColor)
                Text(article.statusDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension ArticleStatus {
    var iconName: String {
        switch self {
        case .pending:
            return "clock"
        case .extracting:
            return "bolt.horizontal.circle"
        case .ready:
            return "doc.text"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var tintColor: Color {
        switch self {
        case .pending:
            return .gray
        case .extracting:
            return .orange
        case .ready:
            return .green
        case .failed:
            return .red
        }
    }
}
