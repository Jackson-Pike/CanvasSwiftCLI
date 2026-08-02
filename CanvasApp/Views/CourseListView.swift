import SwiftUI
import CanvasCore
import CanvasUI

struct CourseListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: CoursesViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Canvas")
                    .font(.headline.bold())
                    .foregroundStyle(Color.byuhRed)
                Spacer()
                HStack(spacing: 4) {
                    Button { refresh(force: true) } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                    .accessibilityLabel("Refresh courses")
                    .help("Refresh courses")
                    Button { appState.navigationPath.append("settings") } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                    .help("Settings")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

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
                                Button("Update Token…") { appState.navigationPath.append("settings") }
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.courses, id: \.id) { course in
                                NavigationLink(destination: CourseDetailView(
                                    course: course,
                                    vm: appState.detailViewModel(for: course)
                                )) {
                                    CourseCard(
                                        name: course.name,
                                        courseCode: course.courseCode,
                                        score: vm.currentScore(for: course.id),
                                        letter: vm.currentScore(for: course.id).map {
                                            letterGrade(for: $0, scale: course.gradingScale)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.hiddenCoursesStore.hide(course.id)
                                    } label: {
                                        Label("Hide Course", systemImage: "eye.slash")
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel({
                                    if let score = vm.currentScore(for: course.id) {
                                        return "\(course.name), \(letterGrade(for: score, scale: course.gradingScale)) grade"
                                    } else {
                                        return course.name
                                    }
                                }())
                                .accessibilityHint("Opens course detail")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .background(Color.systemGroupedBackground)
                }
            }
        }
        .task { refresh() }
    }

    private func refresh(force: Bool = false) {
        guard let client = appState.makeClient() else { return }
        vm.fetch(client: client, force: force)
    }
}
