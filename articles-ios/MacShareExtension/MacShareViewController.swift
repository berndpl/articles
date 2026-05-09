import SwiftData
import SwiftUI

final class MacShareViewController: NSViewController {
    private let model = ShareStateModel()
    private var hasStarted = false

    override func loadView() {
        let hostingController = NSHostingController(rootView: ShareStatusView(model: model))
        addChild(hostingController)
        view = hostingController.view
        view.frame = NSRect(x: 0, y: 0, width: 360, height: 220)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !hasStarted else { return }
        hasStarted = true

        Task { @MainActor in
            await handleShare()
        }
    }

    @MainActor
    private func handleShare() async {
        model.state = .loading("Saving article to Articles...")

        guard let url = await ShareURLExtractor.extractURL(from: extensionContext) else {
            model.state = .failure("No webpage URL was found in this share.")
            scheduleCompletion()
            return
        }

        guard ArticleFolderStore.hasSelectedFolder else {
            model.state = .failure("Open Articles on this Mac and choose a shared folder before saving from Safari.")
            scheduleCompletion()
            return
        }

        let container = SharedStore.makeContainer()
        let context = ModelContext(container)
        let article = await ArticleIngestionService.ingest(url: url, in: context)

        switch article.status {
        case .ready:
            model.state = .success("Saved to Articles")
        case .pending, .extracting:
            model.state = .success("Saving to Articles")
        case .failed:
            model.state = .failure(article.errorMessage ?? "The article could not be extracted.")
        }

        scheduleCompletion()
    }

    private func scheduleCompletion() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
