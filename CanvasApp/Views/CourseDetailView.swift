import SwiftUI
import AppKit
import CanvasCore
import CanvasData
import CanvasUI

struct CourseDetailView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let vm = session.detailViewModel(courseId: courseId)
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
                                .tint(.byuhRed)
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
        .task(id: courseId) { await vm.load(session: session) }
    }
}
