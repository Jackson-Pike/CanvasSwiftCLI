import SwiftUI
import CanvasCore

struct CourseDetailView: View {
    let course: Course
    @ObservedObject var vm: CourseDetailViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if vm.isLoading {
                Color.clear.overlay(ProgressView("Loading grades…"))
            } else if let error = vm.error {
                Color.clear.overlay(
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
                        GradeDashboardView(calc: calc, gradingScale: vm.gradingScale)
                        Divider().padding(.vertical, 8)
                        NavigationLink(destination: CalculatorView(
                            course: course, items: vm.allItems,
                            groupInfo: vm.groupInfo, gradingScale: vm.gradingScale)) {
                            Label("Open Calculator", systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                    }
                }
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

struct GradeDashboardView: View {
    let calc: GradeCalculator
    let gradingScale: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let breakdown = calc.groupBreakdown().sorted { $0.weight > $1.weight }
            ForEach(breakdown, id: \.groupId) { result in
                GroupRowView(result: result, gradingScale: gradingScale)
            }
            Divider()
            HStack {
                Text("Overall").font(.headline)
                Spacer()
                if let overall = calc.currentGrade() {
                    Text(String(format: "%.1f%%", overall))
                        .font(.headline.monospacedDigit()).foregroundStyle(.primary)
                    let letter = letterGrade(for: overall, scale: gradingScale)
                    Text(letter)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.letterGradeColor(letter), in: Capsule())
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct GroupRowView: View {
    let result: GroupResult
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack(spacing: 8) {
            Text(result.name)
                .font(.subheadline).lineLimit(1)
                .frame(width: 120, alignment: .leading)
            Text(String(format: "(%.0f%%)", result.weight))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 40)
            if let pct = result.percent {
                Text(String(format: "%.1f%%", pct))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.primary)
                    .frame(width: 52, alignment: .trailing)
                let letter = letterGrade(for: pct, scale: gradingScale)
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Color.letterGradeColor(letter))
                    .frame(width: 80)
                    .accessibilityValue(String(format: "%.0f percent", pct))
                Text(letter)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.letterGradeColor(letter), in: Capsule())
                    .frame(width: 32)
            } else {
                Text("not graded")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}
