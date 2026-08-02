import SwiftUI
import CanvasCore
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
                        if !vm.streamItems.isEmpty {
                            CourseStreamView(items: vm.streamItems)
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

// MARK: - Course Stream

struct CourseStreamView: View {
    let items: [StreamItem]

    private var awaitingGrade: [StreamItem] {
        items.filter { if case .awaitingGrade = $0.kind { return true }; return false }
    }
    private var upcoming: [StreamItem] {
        items.filter { if case .upcoming = $0.kind { return true }; return false }
    }
    private var recentlyGraded: [StreamItem] {
        items.filter { if case .recentlyGraded = $0.kind { return true }; return false }
    }
    private var recentFeedback: [StreamItem] {
        items.filter { if case .feedback = $0.kind { return true }; return false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.top, 8)
            Text("Course Stream")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if !awaitingGrade.isEmpty {
                StreamSectionHeader(title: "Awaiting Grade", icon: "clock")
                ForEach(awaitingGrade, id: \.assignment.id) { item in
                    StreamRowView(item: item)
                }
            }
            if !upcoming.isEmpty {
                StreamSectionHeader(title: "Upcoming", icon: "calendar")
                ForEach(upcoming, id: \.assignment.id) { item in
                    StreamRowView(item: item)
                }
            }
            if !recentlyGraded.isEmpty {
                StreamSectionHeader(title: "Recently Graded", icon: "checkmark.circle")
                ForEach(recentlyGraded, id: \.assignment.id) { item in
                    StreamRowView(item: item)
                }
            }
            if !recentFeedback.isEmpty {
                StreamSectionHeader(title: "Recent Feedback", icon: "bubble.left")
                ForEach(Array(recentFeedback.enumerated()), id: \.offset) { _, item in
                    StreamRowView(item: item)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct StreamSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

struct StreamRowView: View {
    let item: StreamItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        switch item.kind {
        case .feedback(let authorName, let comment, let createdAt):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.assignment.name)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let date = createdAt {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("\(authorName): \(comment)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

        default:
            HStack(spacing: 6) {
                Text(item.assignment.name)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                inlineDetail
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private var inlineDetail: some View {
        switch item.kind {
        case .awaitingGrade:
            Text("pending")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.12), in: Capsule())

        case .upcoming(let due):
            Text(Self.dateFormatter.string(from: due))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

        case .recentlyGraded(let score, let possible, _):
            if let score, let possible, possible > 0 {
                Text(String(format: "%.0f / %.0f", score, possible))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("graded")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .feedback:
            EmptyView()
        }
    }
}
