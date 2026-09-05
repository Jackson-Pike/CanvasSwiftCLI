import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

/// Full-screen assignment page pushed from the board for deep work. Hosts the read-only
/// context (header, description, rubric, related) plus the submission flow relocated from
/// the docked preview pane.
struct AssignmentDetailPage: View {
    let courseId: Int
    let assignment: CachedAssignment
    let submission: CachedSubmission?
    let status: BoardStatus
    let gradeWeightText: String?

    @Environment(AppSession.self) private var session
    @State private var submissionVM = SubmissionViewModel()
    @State private var showFileImporter = false
    @State private var relatedModules: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AssignmentDetailHeader(assignment: assignment, status: status,
                                       score: submission?.score, gradeWeightText: gradeWeightText)
                submissionSection
                AssignmentReadonlySections(assignment: assignment, submission: submission,
                                           relatedModules: relatedModules)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
        }
        .background(Color.canvasBG)
        .navigationTitle(assignment.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let html = assignment.htmlURL, let url = URL(string: html) {
                    Link("Open in Canvas", destination: url)
                }
            }
        }
        .task(id: assignment.id) {
            submissionVM.load(session: session, assignment: assignment, courseId: courseId)
            relatedModules = (try? session.repository.modulesContaining(assignmentId: assignment.id, courseId: courseId))?
                .map(\.name) ?? []
        }
    }

    // MARK: - Submission (relocated from the docked pane)

    @ViewBuilder
    private var submissionSection: some View {
        let supported = SubmissionType.supported(from: assignment.submissionTypes)
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader("Submission")
            if supported.isEmpty {
                // Unsupported type (quiz, external tool, on-paper) — link out.
                if let html = assignment.htmlURL, let url = URL(string: html) {
                    Link(destination: url) { Label("Submit in Canvas", systemImage: "arrow.up.forward.square") }
                } else {
                    Text("This assignment can't be submitted here.")
                        .font(.system(size: 12)).foregroundStyle(Color.inkTertiary)
                }
            } else {
                SubmissionEditor(
                    types: supported,
                    selection: Binding(get: { submissionVM.selection }, set: { submissionVM.selection = $0 }),
                    text: Binding(get: { submissionVM.text }, set: { submissionVM.text = $0 }),
                    url: Binding(get: { submissionVM.url }, set: { submissionVM.url = $0 }),
                    files: submissionVM.uiFiles,
                    allowedExtensions: submissionVM.allowedExtensions,
                    onAddFiles: { showFileImporter = true },
                    onRemoveFile: { submissionVM.removeFile($0) })

                SubmissionStatusView(phase: submissionVM.phase)

                HStack(spacing: 10) {
                    Button("Submit") { submissionVM.showConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentHypothetical)
                        .disabled(!submissionVM.canSubmit || session.apiClient == nil || submissionVM.isSubmitting)
                    if submissionVM.isSubmitting {
                        // Spec §7: the flow is cancellable up to the final POST.
                        Button("Cancel") { submissionVM.cancel() }
                    }
                    if session.apiClient == nil {
                        Text("Sign in to submit").font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                    }
                    // Failure escape hatch (spec §7): always offer "Open in Canvas" after a failed submit.
                    if case .failed = submissionVM.phase, let html = assignment.htmlURL, let url = URL(string: html) {
                        Link("Open in Canvas", destination: url).font(.system(size: 12))
                    }
                }
            }
        }
        // Autosave text/URL drafts as the user types.
        .onChange(of: submissionVM.text) { _, _ in autosave() }
        .onChange(of: submissionVM.url) { _, _ in autosave() }
        .sheet(isPresented: Binding(get: { submissionVM.showConfirmation },
                                    set: { submissionVM.showConfirmation = $0 })) {
            SubmissionConfirmationSheet(
                assignmentName: assignment.name,
                dueAt: assignment.dueAt,
                isLate: submissionVM.isLate(dueAt: assignment.dueAt),
                attempt: submissionVM.attemptNumber,
                payloadLines: submissionVM.payloadLines(),
                isDemo: session.isDemo,
                onConfirm: { Task { await submissionVM.confirmSubmit(session: session, courseId: courseId, assignment: assignment) } },
                onCancel: { submissionVM.showConfirmation = false })
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { submissionVM.addFiles(urls: urls) }
        }
    }

    private func autosave() {
        Task { await submissionVM.autosaveDraft(session: session, courseId: courseId, assignmentId: assignment.id) }
    }
}
