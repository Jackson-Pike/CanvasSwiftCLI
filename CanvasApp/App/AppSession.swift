import Foundation
import SwiftUI
import SwiftData
import CanvasCore
import CanvasData

@MainActor @Observable
final class AppSession {
    var credentials: Credentials?
    var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")
    var hasAcknowledgedKeychain: Bool = UserDefaults.standard.bool(forKey: "hasAcknowledgedKeychain")
    var syncState: SyncState = .idle
    var host: String = UserDefaults.standard.string(forKey: "canvasHost") ?? "byuh.instructure.com"

    let repository: CanvasRepository
    let syncEngine: SyncEngine
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    var isDemo: Bool { credentials?.token == "DEMO" }
    var hasCredentials: Bool { credentials != nil }

    init() {
        let container: ModelContainer
        do {
            container = try CanvasStore.container()
        } catch {
            // A corrupt store must not brick the app: fall back to in-memory for this run.
            container = try! CanvasStore.container(inMemory: true)
        }
        repository = CanvasRepository(modelContainer: container)
        syncEngine = SyncEngine(modelContainer: container)
        try? repository.purgeExpired()
        if hasAcknowledgedKeychain, let token = KeychainHelper.load(host: host) {
            credentials = Credentials(host: host, token: token)
        }
        Task { await wireEngine() }
    }

    private func wireEngine() async {
        await syncEngine.setStateHandler { [weak self] state in
            Task { @MainActor in self?.syncState = state }
        }
        await syncEngine.configure(client: credentials.map { APIClient(credentials: $0) })
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func acknowledgeKeychain() {
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedKeychain")
        hasAcknowledgedKeychain = true
        if let token = KeychainHelper.load(host: host) {
            credentials = Credentials(host: host, token: token)
            Task { await wireEngine() }
        }
    }

    func saveCredentials(host newHost: String, token rawToken: String) {
        var token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !token.isEmpty else { return }
        KeychainHelper.save(token: token, host: newHost)
        UserDefaults.standard.set(newHost, forKey: "canvasHost")
        host = newHost
        credentials = Credentials(host: newHost, token: token)
        detailVMs = [:]
        Task {
            await wireEngine()
            await refresh(.all, force: true)
        }
    }

    func replaceCredentials(host newHost: String, token: String) {
        try? repository.clearStore()
        saveCredentials(host: newHost, token: token)
    }

    func testConnection(host testHost: String, token: String) async -> Result<Profile, any Error> {
        let client = APIClient(credentials: Credentials(host: testHost, token: token))
        do { return .success(try await client.profile()) }
        catch { return .failure(error) }
    }

    func refresh(_ scope: SyncScope, force: Bool = false) async {
        do { try await syncEngine.refresh(scope, force: force) }
        catch { /* state handler already carries .failed; VMs surface per-section errors */ }
    }

    func detailViewModel(courseId: Int) -> CourseDetailViewModel {
        if let existing = detailVMs[courseId] { return existing }
        let vm = CourseDetailViewModel(courseId: courseId)
        detailVMs[courseId] = vm
        return vm
    }
}
