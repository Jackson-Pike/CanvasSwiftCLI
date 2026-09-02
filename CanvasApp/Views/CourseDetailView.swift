import SwiftUI
import AppKit
import CanvasCore
import CanvasData
import CanvasUI

/// Thin resolver: pulls the cached view model out of the session and hands it to a child
/// that actually *observes* it. Reading `vm` directly in this body would subscribe to
/// nothing — `CourseDetailViewModel` is an `ObservableObject`, so it needs `@ObservedObject`.
struct CourseDetailView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session

    var body: some View {
        CourseDetailBody(courseId: courseId, vm: session.detailViewModel(courseId: courseId))
    }
}

private struct CourseDetailBody: View {
    let courseId: Int
    @ObservedObject var vm: CourseDetailViewModel
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if vm.isLoading {
                Color.systemBackground.overlay(SkeletonList())
            } else if let error = vm.error {
                Color.systemBackground.overlay(
                    ContentUnavailableView {
                        Label("Couldn't Load Grades", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await vm.load(session: session, force: true) } }
                            .buttonStyle(.bordered)
                        if error.contains("Invalid token") {
                            NavigationLink("Update Token…", value: "settings")
                                .buttonStyle(.borderedProminent)
                                .tint(Color.accentHypothetical)
                        }
                    }
                )
            } else if let calc = vm.calculator {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GradeDashboard(
                            breakdown: calc.groupBreakdown().sorted { $0.weight > $1.weight },
                            overall: calc.currentGrade(),
                            gradingScale: calc.gradingScale
                        )
                        Divider().padding(.vertical, 8)
                        if let inputs = vm.inputs {
                            NavigationLink(destination: CalculatorView(
                                items: inputs.items, groupInfo: inputs.groups,
                                gradingScale: inputs.scale,
                                weighted: inputs.weighted)) {
                                Label("Open Calculator", systemImage: "function")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }
                        if !vm.streamItems.isEmpty {
                            StreamSection(items: vm.streamItems)
                        }
                        StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding()
                    }
                }
                .background(Color.systemBackground)
            } else {
                Text("No grade data available.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(vm.courseCode ?? "Course")
        .toolbar {
            ToolbarItem {
                Button {
                    router.reveal(.course(id: courseId, tab: .grades))
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "macwindow")
                }
                .help("Open in Window")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        // Keyed on VM identity, not courseId: `saveCredentials` empties the VM cache, and a
        // courseId-keyed task would not re-fire for the fresh (empty) view model.
        .task(id: ObjectIdentifier(vm)) { await vm.load(session: session) }
    }
}
