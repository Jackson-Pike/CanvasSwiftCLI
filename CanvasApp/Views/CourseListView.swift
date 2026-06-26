import SwiftUI
import CanvasCore

struct CourseListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CoursesViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading courses…").padding()
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await refresh() } }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else if vm.courses.isEmpty {
                Text("No active courses found.")
                    .foregroundStyle(.secondary).padding()
            } else {
                List(vm.courses, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        CourseRowView(course: course, score: vm.currentScore(for: course.id),
                                      gradingScale: course.gradingScale)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client)
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
                    .font(.headline).foregroundStyle(Color.byuhRed)
                Text(course.name)
                    .font(.subheadline).foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            if let score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline).foregroundStyle(Color.byuhGold)
                    let letter = letterGrade(for: score, scale: gradingScale)
                    Text(letter)
                        .font(.subheadline)
                        .foregroundStyle(Color.letterGradeColor(letter))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
