import SwiftData
import SwiftUI
import UserNotifications

@Observable
final class AppState {
    var pendingArticleID: UUID?
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let uuidString = response.notification.request.content.userInfo["articleID"] as? String,
              let uuid = UUID(uuidString: uuidString) else { return }
        await MainActor.run { appState.pendingArticleID = uuid }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct ArticlesApp: App {
    let modelContainer: ModelContainer
    private let appState: AppState
    private let notificationDelegate: NotificationDelegate

    init() {
        modelContainer = SharedStore.makeContainer()
        let state = AppState()
        let delegate = NotificationDelegate(appState: state)
        appState = state
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
    }
}
