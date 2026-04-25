import SwiftUI

enum ShareState: Equatable {
    case idle
    case loading(String)
    case success(String)
    case failure(String)
}

final class ShareStateModel: ObservableObject {
    @Published var state: ShareState = .idle
}

struct ShareStatusView: View {
    @ObservedObject var model: ShareStateModel

    var body: some View {
        VStack(spacing: 16) {
            switch model.state {
            case .idle:
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 36))
                Text("Preparing share...")
                    .foregroundStyle(.secondary)
            case .loading(let message):
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .multilineTextAlignment(.center)
            case .success(let message):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text(message)
                    .multilineTextAlignment(.center)
            case .failure(let message):
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                Text(message)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
