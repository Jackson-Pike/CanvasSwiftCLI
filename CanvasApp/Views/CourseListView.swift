import SwiftUI
import CanvasCore

struct CourseListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: CoursesViewModel

    var body: some View {
        Group {
            if vm.isLoading {
                Color.clear.overlay(ProgressView("Loading courses…"))
            } else if let error = vm.error {
                Color.clear.overlay(
                    ContentUnavailableView {
                        Label("Couldn't Load Courses", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { refresh(force: true) }
                            .buttonStyle(.bordered)
                        if error.contains("Invalid token") || error.contains("unauthorized") {
                            Button("Update Token…") { appState.showingSettings = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.byuhRed)
                        }
                    }
                )
            } else if vm.courses.isEmpty {
                Color.clear.overlay(
                    ContentUnavailableView {
                        Label("No Active Courses", systemImage: "graduationcap")
                    } description: {
                        Text("Courses you're enrolled in this term will appear here.")
                    } actions: {
                        Button("Refresh") { refresh(force: true) }
                            .buttonStyle(.bordered)
                    }
                )
            } else {
                List(vm.courses, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(
                        course: course,
                        vm: appState.detailViewModel(for: course)
                    )) {
                        CourseRowView(course: course, score: vm.currentScore(for: course.id),
                                      gradingScale: course.gradingScale)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            appState.hiddenCoursesStore.hide(course.id)
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { refresh(force: true) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
                .accessibilityLabel("Refresh courses")
                .help("Refresh courses")
            }
            ToolbarItem(placement: .automatic) {
                Button { appState.showingSettings = true } label: {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
                .help("Settings")
            }
        }
        .task { refresh() }
    }

    private func refresh(force: Bool = false) {
        guard let client = appState.makeClient() else { return }
        vm.fetch(client: client, force: force)
    }
}

struct CourseRowView: View {
    let course: Course
    let score: Double?
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.courseCode)
                    .font(.headline).foregroundStyle(.secondary)
                Text(course.name)
                    .font(.subheadline).foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            if let score {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline.monospacedDigit()).foregroundStyle(.primary)
                    let letter = letterGrade(for: score, scale: gradingScale)
                    Text(letter)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.letterGradeColor(letter), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
