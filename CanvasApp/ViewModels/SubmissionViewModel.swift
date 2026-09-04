import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CanvasCore
import CanvasData
import CanvasUI

@MainActor
@Observable
final class SubmissionViewModel {
    var availableTypes: [SubmissionType] = []
    var selection: SubmissionType = .onlineText
    var text: String = ""
    var url: String = ""
    var pickedFiles: [PickedFileEntry] = []
    var phase: SubmissionStatusView.Phase = .idle
    var showConfirmation = false
    var allowedExtensions: [String]?
    private var currentAttempt = 0
    private var submitTask: Task<Void, Never>?

    var isSubmitting: Bool {
        switch phase { case .uploading, .submitting, .verifying: return true; default: return false }
    }

    struct PickedFileEntry: Identifiable {
        var id: UUID { ui.id }
        let ui: SubmissionEditor.PickedFile
        let data: Data
        let contentType: String
    }

    var uiFiles: [SubmissionEditor.PickedFile] { pickedFiles.map(\.ui) }
    var attemptNumber: Int { currentAttempt + 1 }

    func load(session: AppSession, assignment: CachedAssignment, courseId: Int) {
        // Reset per-row editor state unconditionally so a prior row's in-progress edit/upload/phase
        // never bleeds into this one — only the draft-restore block below should repopulate text/url.
        phase = .idle
        pickedFiles = []
        text = ""
        url = ""

        availableTypes = SubmissionType.supported(from: assignment.submissionTypes)
        selection = availableTypes.first ?? .onlineText
        // nil/empty ⇒ any-file-accepted, per SubmissionValidator's documented behavior.
        allowedExtensions = assignment.allowedExtensions
        currentAttempt = (try? session.repository.submission(assignmentId: assignment.id))?.attempt ?? 0
        if let draft = try? session.repository.submissionDraft(assignmentId: assignment.id) {
            text = draft.text ?? ""
            url = draft.url ?? ""
            if let t = SubmissionType(rawValue: draft.submissionTypeRaw), availableTypes.contains(t) { selection = t }
        }
    }

    func addFiles(urls: [URL]) {
        for fileURL in urls {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if didAccess { fileURL.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            let name = fileURL.lastPathComponent
            let allowed = SubmissionValidator.isExtensionAllowed(name, allowed: allowedExtensions)
            let ui = SubmissionEditor.PickedFile(filename: name, sizeBytes: data.count, isAllowed: allowed)
            let ctype = contentType(for: fileURL)
            pickedFiles.append(PickedFileEntry(ui: ui, data: data, contentType: ctype))
        }
    }

    func removeFile(_ id: UUID) { pickedFiles.removeAll { $0.id == id } }

    var canSubmit: Bool {
        switch selection {
        case .onlineText:   return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .onlineURL:    return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .onlineUpload: return !pickedFiles.isEmpty && pickedFiles.allSatisfy { $0.ui.isAllowed }
        }
    }

    func payloadLines() -> [String] {
        switch selection {
        case .onlineText:   return ["Text: \(text.count) characters"]
        case .onlineURL:    return [url]
        case .onlineUpload: return pickedFiles.map { "\($0.ui.filename) (\(byteString($0.ui.sizeBytes)))" }
        }
    }

    func isLate(dueAt: Date?) -> Bool { dueAt.map { Date() > $0 } ?? false }

    func autosaveDraft(session: AppSession, courseId: Int, assignmentId: Int) async {
        // Only text/URL persist (spec §7 decision). Skip pure-file drafts.
        guard selection != .onlineUpload else { return }
        await session.saveSubmissionDraft(assignmentId: assignmentId, courseId: courseId,
                                          type: selection, text: text, url: url)
    }

    func confirmSubmit(session: AppSession, courseId: Int, assignment: CachedAssignment) async {
        showConfirmation = false
        let files = pickedFiles.map {
            SyncEngine.SubmissionFile(filename: $0.ui.filename, contentType: $0.contentType, data: $0.data)
        }
        phase = selection == .onlineUpload ? .uploading(current: 1, total: max(files.count, 1)) : .submitting

        // Run inside a cancellable Task so the user can back out during uploads (before the final POST).
        let sel = selection, t = text, u = url
        submitTask = Task { [weak self] in
            let result = await session.submit(courseId: courseId, assignmentId: assignment.id,
                                              type: sel, text: t, url: u, files: files)
            guard let self, !Task.isCancelled else { return }
            switch result {
            case .success(let sub):
                self.phase = .success(attempt: sub.attempt ?? self.attemptNumber, submittedAt: sub.submittedAt)
            case .failure(let message):
                self.phase = .failed(message)   // draft already persisted via autosave; retry stays available
            }
        }
        await submitTask?.value
    }

    /// Cancels an in-flight submit. The engine's per-file upload uses URLSession, which throws on
    /// cancellation before the submission POST — so a cancel here leaves the assignment unsubmitted
    /// with the draft intact. No effect once verification has returned success.
    func cancel() {
        guard isSubmitting else { return }
        submitTask?.cancel()
        phase = .idle
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func contentType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType { return mime }
        return "application/octet-stream"
    }
}
