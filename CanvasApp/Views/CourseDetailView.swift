import SwiftUI
import CanvasCore

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: CourseDetailViewModel

    init(course: Course) {
        self.course = course
        _vm = StateObject(wrappedValue: CourseDetailViewModel(course: course))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading grades…").padding()
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await refresh() } }.buttonStyle(.bordered)
                }
                .padding()
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

    private func refresh() async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client)
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
                        .font(.headline).foregroundStyle(Color.byuhGold)
                    let letter = letterGrade(for: overall, scale: gradingScale)
                    Text(letter).font(.headline)
                        .foregroundStyle(Color.letterGradeColor(letter))
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
                    .font(.subheadline).foregroundStyle(Color.byuhGold)
                    .frame(width: 52, alignment: .trailing)
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Color.byuhRed)
                    .frame(width: 80)
                let letter = letterGrade(for: pct, scale: gradingScale)
                Text(letter).font(.caption.bold())
                    .foregroundStyle(Color.letterGradeColor(letter))
                    .frame(width: 24)
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
