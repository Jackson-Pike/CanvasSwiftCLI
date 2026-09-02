import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct ToDoView: View {
    @Environment(AppSession.self) private var session
    @State private var viewModel = ToDoViewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("To-Do Triage")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.inkPrimary)

                Spacer()

                Button {
                    Task { await viewModel.load(session: session) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.isLoading {
                ProgressView("Loading items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading to-do items: \(error)")
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await viewModel.load(session: session) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.missingItems.isEmpty && viewModel.dueThisWeekItems.isEmpty && viewModel.awaitingGradeItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("You're all caught up!")
                        .font(.headline)
                        .foregroundColor(.inkPrimary)
                    Text("No missing work or upcoming deadlines this week.")
                        .font(.subheadline)
                        .foregroundColor(.inkSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !viewModel.missingItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ToDoSectionHeader(
                                    title: "Missing Work",
                                    iconName: "exclamationmark.triangle.fill",
                                    iconColor: .lostMissing,
                                    count: viewModel.missingItems.count
                                )
                                ForEach(viewModel.missingItems) { item in
                                    let color = item.courseId.flatMap { viewModel.courseColors[$0] } ?? .lostMissing
                                    ToDoItemRow(item: item, courseColor: color, onItemClick: handleItemClick)
                                }
                            }
                        }

                        if !viewModel.dueThisWeekItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ToDoSectionHeader(
                                    title: "Due This Week",
                                    iconName: "clock.fill",
                                    iconColor: .orange,
                                    count: viewModel.dueThisWeekItems.count
                                )
                                ForEach(viewModel.dueThisWeekItems) { item in
                                    let color = item.courseId.flatMap { viewModel.courseColors[$0] } ?? .orange
                                    ToDoItemRow(item: item, courseColor: color, onItemClick: handleItemClick)
                                }
                            }
                        }

                        if !viewModel.awaitingGradeItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ToDoSectionHeader(
                                    title: "Awaiting Grade",
                                    iconName: "hourglass",
                                    iconColor: Color.accentHypothetical,
                                    count: viewModel.awaitingGradeItems.count
                                )
                                ForEach(viewModel.awaitingGradeItems) { item in
                                    let color = item.courseId.flatMap { viewModel.courseColors[$0] } ?? Color.accentHypothetical
                                    ToDoItemRow(item: item, courseColor: color, onItemClick: handleItemClick)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(Color.canvasBG)
        .task {
            await viewModel.load(session: session)
        }
    }

    private func handleItemClick(_ item: ToDoItem) {
        if let urlString = item.htmlUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
