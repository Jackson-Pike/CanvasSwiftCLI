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
    @State private var showSettings = false

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(CourseTab.allCases, id: \.self) { tab in
                        let selected = router.courseTab == tab
                        Button {
                            router.courseTab = tab
                        } label: {
                            Text(tab.rawValue.capitalized)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? Color.accentHypothetical : Color.inkSecondary)
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(selected ? Color.accentHypothetical : Color.clear)
                                        .frame(height: 2)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.canvasHairline).frame(height: 1)
            }
            if router.courseTab == .grades {
                GradesTabView(vm: vm, onFixCredentials: { showSettings = true })
            } else if router.courseTab == .assignments {
                AssignmentsTabView(courseId: courseId).id(courseId)
            } else if router.courseTab == .announcements {
                AnnouncementsTabView(courseId: courseId).id(courseId)
            } else if router.courseTab == .syllabus {
                SyllabusTabView(courseId: courseId)
            } else if router.courseTab == .discussions {
                DiscussionsTabView(courseId: courseId).id(courseId)
            } else if router.courseTab == .modules {
                ModulesTabView(courseId: courseId).id(courseId)
            } else if router.courseTab == .files {
                FilesTabView(courseId: courseId).id(courseId)
            }
        }
        .navigationTitle(vm.courseCode ?? "Course")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $router.sandboxOpen) { Image(systemName: "function") }
                    .help("What-If Sandbox")
                    .accessibilityLabel("What-If Sandbox")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isOnboarding: false, vm: session.coursesVM)
                .frame(minHeight: 420)   // SettingsView sets its own 340pt width
        }
        .task(id: ObjectIdentifier(vm)) { await vm.load(session: session) }
    }
}

struct GradesTabView: View {
    @ObservedObject var vm: CourseDetailViewModel
    var onFixCredentials: () -> Void = {}

    var body: some View {
        Group {
            if let inputs = vm.inputs {
                GradesSandboxSplit(courseId: vm.courseId, inputs: inputs,
                                   streamItems: vm.streamItems, lastSyncedAt: vm.lastSyncedAt)
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
                            .tint(Color.accentHypothetical)
                    }
                }
            } else {
                Text("No grade data available.").foregroundStyle(.secondary)
            }
        }
    }
}

/// Owns the shared `CalculatorViewModel` for the loaded-grades state and docks the
/// `SandboxRailView` alongside the main grades column (spec §2 "Course workspace + Sandbox").
/// `CalculatorViewModel` needs non-optional inputs at init, so this is split out of
/// `GradesTabView` (which still has to handle the optional/loading/error states).
private struct GradesSandboxSplit: View {
    @StateObject private var calc: CalculatorViewModel
    let courseId: Int
    let streamItems: [StreamItem]
    let lastSyncedAt: Date?
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session

    init(courseId: Int, inputs: CalculatorInputs, streamItems: [StreamItem], lastSyncedAt: Date?) {
        _calc = StateObject(wrappedValue: CalculatorViewModel(
            items: inputs.items, groupInfo: inputs.groups, gradingScale: inputs.scale, weighted: inputs.weighted))
        self.courseId = courseId
        self.streamItems = streamItems
        self.lastSyncedAt = lastSyncedAt
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                mainColumn
            }
            .frame(maxWidth: .infinity)
            if router.sandboxOpen {
                SandboxRailView(vm: calc)
                    .frame(width: 330)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.sandboxOpen)
    }

    // MARK: - Main column

    private var actualCalculator: GradeCalculator {
        GradeCalculator(items: calc.baseItems, groups: calc.groupInfo,
                        weighted: calc.weighted, gradingScale: calc.gradingScale)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            headline
            groupsSection
            trendSection
            assignmentsSection
            if !streamItems.isEmpty {
                StreamSection(items: streamItems)
            }
            StalenessLabel(lastSyncedAt: lastSyncedAt)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    private var headline: some View {
        let actual = actualCalculator.currentGrade()
        let projected = calc.liveGrade
        let projectedLetter = projected.map { letterGrade(for: $0, scale: calc.gradingScale) }
        let activeCount = calc.whatIfEntries.values.filter { $0.isActive }.count

        return HStack(alignment: .firstTextBaseline, spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Actual").font(.sectionLabel).foregroundStyle(Color.inkSecondary)
                Text(actual.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.mono(40, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Projected").font(.sectionLabel).foregroundStyle(Color.accentHypothetical)
                HStack(spacing: 8) {
                    Text(projected.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.mono(40, weight: .bold))
                        .foregroundStyle(Color.accentHypothetical)
                    if let projectedLetter {
                        LetterBadge(letter: projectedLetter)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(activeCount == 1 ? "1 hypothetical active" : "\(activeCount) hypotheticals active")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkTertiary)
                if activeCount > 0 {
                    Button("Reset sandbox") { calc.whatIfEntries.removeAll() }
                        .font(.system(size: 11.5, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentHypothetical)
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: projected)
    }

    private var groupsSection: some View {
        let actualBreakdown = actualCalculator.groupBreakdown().sorted { $0.weight > $1.weight }
        let liveByGroup = Dictionary(uniqueKeysWithValues: calc.liveBreakdown.map { ($0.groupId, $0) })

        return VStack(alignment: .leading, spacing: 6) {
            Text("Groups").font(.sectionLabel).foregroundStyle(Color.inkSecondary)
            ForEach(actualBreakdown, id: \.groupId) { result in
                let livePercent = liveByGroup[result.groupId]?.percent
                let lifted = (livePercent ?? 0) > (result.percent ?? 0) + 0.05
                GroupLiftRow(result: result, livePercent: livePercent, lifted: lifted, gradingScale: calc.gradingScale)
            }
        }
    }

    /// `GradeSnapshot` rows are only written when a score actually *changes*, so a freshly
    /// synced course legitimately has too few points to plot — the chart owns that empty state.
    private var trendSection: some View {
        let snapshots = (try? session.repository.gradeSnapshots(courseId: courseId)) ?? []
        let points = snapshots.map { GradeTrendChart.Point(date: $0.capturedAt, percent: $0.percent) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Trend").font(.sectionLabel).foregroundStyle(Color.inkSecondary)
            GradeTrendChart(points: points, gradingScale: calc.gradingScale)
                .frame(height: 160)
        }
    }

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Assignments").font(.sectionLabel).foregroundStyle(Color.inkSecondary)
            ForEach(calc.baseItems, id: \.assignmentId) { item in
                AssignmentRow(item: item, entry: calc.whatIfEntries[item.assignmentId], gradingScale: calc.gradingScale)
            }
        }
    }
}

/// One `GROUPS` row: real percent track in `letterGradeColor`, with any what-if lift
/// appended as an accent segment.
private struct GroupLiftRow: View {
    let result: GroupResult
    let livePercent: Double?
    let lifted: Bool
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack(spacing: 8) {
            Text(result.name)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
            Text(String(format: "%.0f%%", result.weight))
                .font(.mono(11))
                .foregroundStyle(Color.inkTertiary)
                .frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.barTrack)
                    if let base = result.percent {
                        Capsule()
                            .fill(Color.letterGradeColor(letterGrade(for: base, scale: gradingScale)))
                            .frame(width: geo.size.width * CGFloat(min(base, 100) / 100))
                    }
                    if let live = livePercent, let base = result.percent, live > base {
                        Capsule()
                            .fill(Color.accentHypothetical)
                            .frame(width: geo.size.width * CGFloat(min(live, 100) / 100))
                            .mask(alignment: .trailing) {
                                Rectangle().frame(width: geo.size.width * CGFloat((min(live, 100) - base) / 100))
                            }
                    }
                }
            }
            .frame(height: 8)
            Text((livePercent ?? result.percent).map { String(format: "%.1f%%", $0) } ?? "—")
                .font(.mono(11.5))
                .foregroundStyle(lifted ? Color.accentHypothetical : Color.inkPrimary)
                .frame(width: 52, alignment: .trailing)
        }
        .animation(.easeOut(duration: 0.18), value: livePercent)
    }
}

/// One `ASSIGNMENTS` row. Hypothetical rows (active `whatIfEntry`) get an accent-tinted
/// fill + 1pt accent border and an accent `what-if <pts>/<possible>` capsule.
private struct AssignmentRow: View {
    let item: GradedItem
    let entry: CalculatorViewModel.WhatIfEntry?
    let gradingScale: [(String, Double)]

    private var isHypothetical: Bool { entry?.isActive == true }

    var body: some View {
        HStack {
            Text(item.name)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            Spacer()
            if isHypothetical, let pts = entry?.resolvedPoints(possiblePoints: item.pointsPossible) {
                Text(String(format: "what-if %.0f/%.0f", pts, item.pointsPossible))
                    .font(.mono(11, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentHypothetical, in: Capsule())
            } else if let earned = item.earnedPoints {
                Text(String(format: "%.0f/%.0f", earned, item.pointsPossible))
                    .font(.mono(11.5))
                    .foregroundStyle(Color.inkSecondary)
            } else {
                Text(String(format: "—/%.0f", item.pointsPossible))
                    .font(.mono(11.5))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isHypothetical ? Color.accentHypothetical.opacity(0.08) : Color.inkPrimary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHypothetical ? Color.accentHypothetical : .clear, lineWidth: 1)
        )
    }
}
