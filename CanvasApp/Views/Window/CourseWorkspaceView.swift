import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct CourseWorkspaceView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session

    var body: some View {
        CourseWorkspaceBody(courseId: courseId, vm: session.detailViewModel(courseId: courseId))
    }
}

/// Observes the view model so `courseCode` (navigation title) and the load task track it.
private struct CourseWorkspaceBody: View {
    let courseId: Int
    @ObservedObject var vm: CourseDetailViewModel
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @State private var showCalculator = false
    @State private var showSettings = false

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Picker("Tab", selection: $router.courseTab) {
                ForEach(CourseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue.capitalized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            Divider()
            if router.courseTab == .grades {
                GradesTabView(vm: vm, showCalculator: $showCalculator,
                              onFixCredentials: { showSettings = true })
            } else {
                ComingSoonView(title: router.courseTab.rawValue.capitalized, phase: "a later phase")
            }
        }
        .navigationTitle(vm.courseCode ?? "Course")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showCalculator) { Image(systemName: "function") }
                    .help("What-If Calculator")
                    .accessibilityLabel("What-If Calculator")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isOnboarding: false, vm: session.coursesVM)
                .frame(minWidth: 460, minHeight: 420)
        }
        .task(id: ObjectIdentifier(vm)) { await vm.load(session: session) }
    }
}

struct GradesTabView: View {
    @ObservedObject var vm: CourseDetailViewModel
    @Binding var showCalculator: Bool
    var onFixCredentials: () -> Void = {}

    var body: some View {
        Group {
            if let calc = vm.calculator {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GradeDashboard(breakdown: calc.groupBreakdown().sorted { $0.weight > $1.weight },
                                       overall: calc.currentGrade(),
                                       gradingScale: calc.gradingScale)
                        if !vm.streamItems.isEmpty {
                            StreamSection(items: vm.streamItems)
                        }
                        StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding()
                    }
                }
            } else if vm.isLoading {
                SkeletonList()                       // cold, no cache (spec §5.8)
            } else if let error = vm.error {
                ContentUnavailableView {
                    Label("Couldn't Load Grades", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    if error.contains("Invalid token") {
                        Button("Update Token…", action: onFixCredentials)
                            .buttonStyle(.borderedProminent)
                            .tint(.byuhRed)
                    }
                }
            } else {
                Text("No grade data available.").foregroundStyle(.secondary)
            }
        }
        .inspector(isPresented: $showCalculator) {
            if let inputs = vm.inputs {
                CalculatorView(items: inputs.items, groupInfo: inputs.groups,
                               gradingScale: inputs.scale, weighted: inputs.weighted)
                    .inspectorColumnWidth(min: 300, ideal: 340)
            }
        }
    }
}
