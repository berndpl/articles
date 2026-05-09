import SwiftData
import SwiftUI
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

        guard let url = await ShareURLExtractor.extractURL(from: extensionContext) else {
            model.state = .failure("No webpage URL was found in this share.")
            scheduleCompletion()
            return
        }

        guard ArticleFolderStore.hasSelectedFolder else {
            model.state = .failure("Open Articles and choose a shared folder before saving from the share sheet.")
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

}
