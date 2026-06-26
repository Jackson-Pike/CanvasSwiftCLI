import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = KeychainHelper.load()
    @Published var showingSettings = false

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(token: trimmed)
        token = trimmed
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(token: token)
    }
}
