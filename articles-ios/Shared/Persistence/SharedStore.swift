import Foundation
import SwiftData

enum AppGroupConfiguration {
    static let identifier = "group.de.plontsch.Articles"
    static let sqliteName = "Articles.sqlite"

    static var storeURL: URL {
        let fileManager = FileManager.default
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Store", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(sqliteName)
    }
}

enum SharedStore {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Article.self])
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let storeURL = persistentStoreURL()
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create model container: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func makePreviewContainer() -> ModelContainer {
        let container = makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Article.previewReady)
        try? context.save()
        return container
    }

    private static func persistentStoreURL() -> URL {
        AppGroupConfiguration.storeURL
    }
}
