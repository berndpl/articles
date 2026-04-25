import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import UserNotifications
import WidgetKit

final class ShareViewController: UIViewController {
    private let model = ShareStateModel()
    private var hasStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: ShareStatusView(model: model))
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true

        Task { @MainActor in
            await handleShare()
        }
    }

    @MainActor
    private func handleShare() async {
        model.state = .loading("Saving article to Articles…")

        guard let url = await extractURL() else {
            model.state = .failure("No webpage URL was found in this share.")
            scheduleCompletion()
            return
        }

        let container = SharedStore.makeContainer()
        let context = ModelContext(container)
        let article = await ArticleIngestionService.ingest(url: url, in: context)

        switch article.status {
        case .ready:
            model.state = .success("Saved to Articles")
            await scheduleNotification(for: article)
            WidgetCenter.shared.reloadAllTimelines()
        case .pending, .extracting:
            model.state = .success("Saving to Articles")
            await scheduleNotification(for: article)
            WidgetCenter.shared.reloadAllTimelines()
        case .failed:
            model.state = .failure(article.errorMessage ?? "The article could not be extracted.")
        }

        scheduleCompletion()
    }

    private func scheduleNotification(for article: Article) async {
        let content = UNMutableNotificationContent()
        content.title = "Saved to Articles"
        content.body = article.displayTitle
        content.sound = .default
        content.userInfo = ["articleID": article.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: article.id.uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleCompletion() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func extractURL() async -> URL? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else { return nil }

        for provider in item.attachments ?? [] {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier),
               let url = item as? URL {
                return url
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
               let string = item as? String,
               let url = URL(string: string) {
                return url
            }
        }

        return nil
    }
}
