import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry

struct ArticleEntry: TimelineEntry {
    let date: Date
    let title: String
    let domain: String
    let previewText: String
    let articleID: String?

    static let placeholder = ArticleEntry(
        date: .now,
        title: "Article Title",
        domain: "example.com",
        previewText: "A preview of the article content goes here.",
        articleID: nil
    )

    static let empty = ArticleEntry(
        date: .now,
        title: "No articles yet",
        domain: "",
        previewText: "Share a URL from Safari to get started.",
        articleID: nil
    )
}

// MARK: - Provider

struct ArticlesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArticleEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ArticleEntry) -> Void) {
        completion(fetchLatest() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArticleEntry>) -> Void) {
        let entry = fetchLatest() ?? .empty
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func fetchLatest() -> ArticleEntry? {
        let schema = Schema([Article.self])
        let config = ModelConfiguration(schema: schema, url: AppGroupConfiguration.storeURL)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else { return nil }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\Article.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        guard let articles = try? context.fetch(descriptor),
              let article = articles.first(where: { $0.status == .ready }) else { return nil }
        return ArticleEntry(
            date: .now,
            title: article.displayTitle,
            domain: article.sourceDomain,
            previewText: article.previewText,
            articleID: article.id.uuidString
        )
    }
}

// MARK: - View

struct ArticlesWidgetView: View {
    let entry: ArticleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App label
            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.caption2)
                    .foregroundStyle(.accent)
                Text("Articles")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 8)

            // Title
            Text(entry.title)
                .font(family == .systemSmall ? .subheadline : .headline)
                .fontWeight(.semibold)
                .lineLimit(family == .systemSmall ? 4 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Preview — medium only
            if family != .systemSmall, !entry.previewText.isEmpty {
                Text(entry.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)

            // Domain
            if !entry.domain.isEmpty {
                Text(entry.domain)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(for: .widget) { Color(.systemBackground) }
        .widgetURL(widgetURL)
    }

    private var widgetURL: URL? {
        guard let id = entry.articleID else { return URL(string: "articles://open") }
        return URL(string: "articles://article?id=\(id)")
    }
}

// MARK: - Widget

struct ArticlesWidget: Widget {
    let kind = "ArticlesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArticlesWidgetProvider()) { entry in
            ArticlesWidgetView(entry: entry)
        }
        .configurationDisplayName("Latest Article")
        .description("Shows your most recently saved article.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ArticlesWidget()
} timeline: {
    ArticleEntry.placeholder
}

#Preview(as: .systemMedium) {
    ArticlesWidget()
} timeline: {
    ArticleEntry.placeholder
}
