import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct AssignmentsTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @StateObject private var vm: AssignmentsViewModel

    init(courseId: Int) {
        self.courseId = courseId
        _vm = StateObject(wrappedValue: AssignmentsViewModel(courseId: courseId))
    }

    var body: some View {
        Group {
            if !vm.rows.isEmpty {
                HStack(spacing: 0) {
                    listColumn
                        .frame(width: 320)
                    Divider()
                    detailColumn
                        .frame(maxWidth: .infinity)
                }
            } else if vm.isLoading {
                SkeletonList()
            } else if let error = vm.error {
                ContentUnavailableView {
                    Label("Couldn't Load Assignments", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView {
                    Label("No Assignments", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("This course has no assignments yet.")
                }
            }
        }
        .background(Color.canvasBG)
        .task(id: courseId) {
            await vm.load(session: session)
            consumeDeepLink()
        }
    }

    /// Consumes `RevealTarget.assignment`, set by the Dashboard's Awaiting Grade and
    /// Recent Feedback panels. Cleared so a later tab visit doesn't re-select it.
    private func consumeDeepLink() {
        guard let target = router.selectedAssignmentId else { return }
        vm.filter = .all                      // the target may not match the default filter
        vm.select(target, session: session)
        router.selectedAssignmentId = nil
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            AssignmentFilterChips(selected: $vm.filter)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.filteredRows) { row in
                        AssignmentListRow(name: row.assignment.name,
                                          dueAt: row.assignment.dueAt,
                                          pointsPossible: row.assignment.pointsPossible,
                                          score: row.submission?.score,
                                          workflowState: row.submission?.workflowState,
                                          isMissing: isMissing(row),
                                          isSelected: vm.selectedAssignmentId == row.assignment.id,
                                          onTap: { vm.select(row.assignment.id, session: session) })
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private func isMissing(_ row: AssignmentsViewModel.Row) -> Bool {
        isAssignmentMissing(dueAt: row.assignment.dueAt,
                            submissionWorkflowState: row.submission?.workflowState,
                            missingFlag: row.submission?.missing,
                            now: Date())
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let row = vm.selectedRow {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(row.assignment.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    metadataBlock(row)
                    RichTextView(html: row.assignment.descriptionHTML ?? "<p>No description.</p>")
                    rubricSection(row)
                    commentsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        } else {
            ContentUnavailableView {
                Label("Select an Assignment", systemImage: "doc.text")
            } description: {
                Text("Pick an assignment from the list to see its details.")
            }
        }
    }

    private func metadataBlock(_ row: AssignmentsViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 14) {
                metadataItem("Due", date: row.assignment.dueAt)
                metadataItem("Available", date: row.assignment.unlockAt)
                metadataItem("Closes", date: row.assignment.lockAt)
            }
            HStack(spacing: 8) {
                Text(scoreText(row))
                    .font(.mono(12))
                    .foregroundStyle(Color.inkPrimary)
                ForEach(row.assignment.submissionTypes, id: \.self) { type in
                    Text(type.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(Color.canvasHairline, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func metadataItem(_ label: String, date: Date?) -> some View {
        if let date {
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private func scoreText(_ row: AssignmentsViewModel.Row) -> String {
        let possible = row.assignment.pointsPossible.map { String(format: "%.0f", $0) } ?? "—"
        let earned = row.submission?.score.map { String(format: "%.1f", $0) } ?? "—"
        return "\(earned)/\(possible) pts"
    }

    @ViewBuilder
    private func rubricSection(_ row: AssignmentsViewModel.Row) -> some View {
        let criteria = row.assignment.rubric
        if !criteria.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("RUBRIC").font(.sectionLabel).tracking(0.6).foregroundStyle(Color.inkSecondary)
                RubricTable(lines: formatRubricAssessment(
                    criteria: criteria,
                    assessment: row.submission?.rubricAssessment ?? [:]))
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        let comments = vm.instructorComments
        if !comments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("FEEDBACK").font(.sectionLabel).tracking(0.6).foregroundStyle(Color.inkSecondary)
                ForEach(comments, id: \.id) { comment in
                    InstructorCommentRow(authorName: comment.authorName,
                                         comment: comment.body,
                                         createdAt: comment.createdAt)
                }
            }
        }
    }
}
