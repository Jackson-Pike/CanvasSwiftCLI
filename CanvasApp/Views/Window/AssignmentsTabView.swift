import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct AssignmentsTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @StateObject private var vm: AssignmentsViewModel
    @State private var openedAssignmentId: Int?

    init(courseId: Int) {
        self.courseId = courseId
        _vm = StateObject(wrappedValue: AssignmentsViewModel(courseId: courseId))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $openedAssignmentId) { id in
                    if let row = vm.rows.first(where: { $0.id == id }) {
                        AssignmentDetailPage(courseId: courseId,
                                             assignment: row.assignment,
                                             submission: row.submission,
                                             status: vm.boardStatus(for: row),
                                             gradeWeightText: vm.gradeWeightText(for: row))
                    }
                }
        }
        .background(Color.canvasBG)
        .task(id: courseId) {
            await vm.load(session: session)
            consumeDeepLink()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !vm.rows.isEmpty {
            HStack(spacing: 0) {
                boardColumn
                    .frame(maxWidth: .infinity)
                Divider()
                detailColumn
                    .frame(width: 392)
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

    /// Consumes `RevealTarget.assignment`, set by the Dashboard's Awaiting Grade and
    /// Recent Feedback panels. Cleared so a later tab visit doesn't re-select it.
    private func consumeDeepLink() {
        guard let target = router.selectedAssignmentId else { return }
        vm.select(target, session: session)   // grouping shows every assignment, so no filter to relax
        router.selectedAssignmentId = nil
    }

    // MARK: - Board

    private var boardColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                AssignmentGroupByControl(selected: $vm.grouping)
                Spacer(minLength: 8)
                BoardSummaryLine(dueThisWeek: vm.dueThisWeek, ledger: vm.ledger)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(vm.boardColumns) { col in
                        AssignmentBoardColumn(label: col.label, tint: col.tint,
                                              count: col.count, meta: col.meta) {
                            ForEach(col.rows) { row in
                                AssignmentBoardCard(
                                    name: row.assignment.name,
                                    dueAt: row.assignment.dueAt,
                                    pointsPossible: row.assignment.pointsPossible,
                                    kind: assignmentKind(submissionTypes: row.assignment.submissionTypes),
                                    gradedText: gradedChipText(row),
                                    isSelected: vm.selectedAssignmentId == row.id,
                                    onTap: { vm.select(row.id, session: session) },
                                    onOpen: { open(row) })
                            }
                        }
                    }
                }
                .padding(14)
            }

            StalenessLabel(lastSyncedAt: vm.lastSyncedAt)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    /// Score text shown on a card's chip when the assignment is graded, else nil.
    private func gradedChipText(_ row: AssignmentsViewModel.Row) -> String? {
        guard vm.boardStatus(for: row) == .graded, let score = row.submission?.score else { return nil }
        return AssignmentDetailFormat.points(score)
    }

    private func open(_ row: AssignmentsViewModel.Row) {
        vm.select(row.id, session: session)   // refresh related-modules for the pushed page
        openedAssignmentId = row.id
    }

    // MARK: - Docked preview pane

    @ViewBuilder
    private var detailColumn: some View {
        if let row = vm.selectedRow {
            let status = vm.boardStatus(for: row)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AssignmentDetailHeader(assignment: row.assignment, status: status,
                                           score: row.submission?.score,
                                           gradeWeightText: vm.gradeWeightText(for: row))

                    Button {
                        open(row)
                    } label: {
                        Text(assignmentCTALabel(status))
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentHypothetical)

                    AssignmentReadonlySections(assignment: row.assignment,
                                               submission: row.submission,
                                               relatedModules: vm.relatedModuleNames)

                    commentsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        } else {
            ContentUnavailableView {
                Label("Select an Assignment", systemImage: "doc.text")
            } description: {
                Text("Pick an assignment from the board to see its details.")
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        let comments = vm.instructorComments
        if !comments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                DetailSectionHeader("Feedback")
                ForEach(comments, id: \.id) { comment in
                    InstructorCommentRow(authorName: comment.authorName,
                                         comment: comment.body,
                                         createdAt: comment.createdAt)
                }
            }
        }
    }
}
