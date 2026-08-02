import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct CourseDetailView: View {
    let course: Course
    @ObservedObject var vm: CourseDetailViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if vm.isLoading {
                Color.systemBackground.overlay(ProgressView("Loading grades…"))
            } else if let error = vm.error {
                Color.systemBackground.overlay(
                    ContentUnavailableView {
                        Label("Couldn't Load Grades", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await refresh(force: true) } }.buttonStyle(.bordered)
                    }
                )
            } else if let calc = vm.calculator {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GradeDashboard(
                            breakdown: calc.groupBreakdown().sorted { $0.weight > $1.weight },
                            overall: calc.currentGrade(),
                            gradingScale: vm.gradingScale
                        )
                        Divider().padding(.vertical, 8)
                        NavigationLink(destination: CalculatorView(
                            items: vm.allItems, groupInfo: vm.groupInfo,
                            gradingScale: vm.gradingScale,
                            weighted: course.applyAssignmentGroupWeights ?? false)) {
                            Label("Open Calculator", systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        if !vm.streamItems.isEmpty {
                            StreamSection(items: vm.streamItems)
                        }
                    }
                }
                .background(Color.systemBackground)
            } else {
                Text("No grade data available.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(course.courseCode)
        .task { await refresh() }
    }

    private func refresh(force: Bool = false) async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client, force: force)
    }
}
