import SwiftUI
import CanvasCore
import CanvasUI

/// Term-scope What-If Sandbox rail, docked into `DashboardView` behind
/// `router.sandboxOpen` (handoff §2 "Dashboard-scope variant"). Mirrors
/// `SandboxRailView`'s (course-scope) chrome — same panel background, hairline
/// border, header shape — but every number here is a term GPA built from
/// `TermScenarioViewModel` + `CanvasCore`'s `[CourseGradeSummary]` functions,
/// not a single course's `GradeCalculator`.
struct TermSandboxRail: View {
    @Bindable var vm: TermScenarioViewModel

    private let targetOptions: [Double] = [3.5, 3.7, 4.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.canvasHairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    targetSection
                    suggestionSentence
                    slidersSection
                    summaryCard
                    if let message = vm.unreachableMessage {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
            }
            Divider().overlay(Color.canvasHairline)
            footer
        }
        .frame(width: 296)
        .background(Color.canvasPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.canvasHairline).frame(width: 1)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Sandbox")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                scopeChip
                Spacer()
            }
            Text("Nothing here is sent to Canvas.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(16)
    }

    private var scopeChip: some View {
        Text("TERM")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.canvasBG))
            .overlay(Capsule().stroke(Color.canvasHairlineStrong, lineWidth: 1))
    }

    // MARK: - Target chips

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I Want to Finish With")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            HStack(spacing: 6) {
                ForEach(targetOptions, id: \.self) { target in
                    chip(label: String(format: "%.1f", target), selected: vm.targetGPA == target) {
                        vm.targetGPA = target
                    }
                }
            }
        }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? Color.onAccent : Color.inkPrimary)
                .background(Capsule().fill(selected ? Color.accentHypothetical : Color.canvasBG))
                .overlay(Capsule().stroke(Color.canvasHairlineStrong, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Suggestion sentence

    @ViewBuilder
    private var suggestionSentence: some View {
        if let suggestion = vm.suggestion {
            (Text("Pull ").foregroundStyle(Color.inkSecondary)
                + Text(suggestion.code).bold().foregroundStyle(Color.inkPrimary)
                + Text(" to a ").foregroundStyle(Color.inkSecondary)
                + Text(suggestion.letter).bold().foregroundStyle(Color.accentHypothetical)
                + Text(" and hold everything else. That's ").foregroundStyle(Color.inkSecondary)
                + Text("\(Int(suggestion.requiredPercent.rounded()))%").bold().foregroundStyle(Color.accentHypothetical)
                + Text(" on the remaining work.").foregroundStyle(Color.inkSecondary))
                .font(.system(size: 13.5))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Sliders

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remaining Work")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            let candidates = vm.summaries.filter { $0.nowPercent != nil }
            if candidates.isEmpty {
                Text("No graded courses yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkTertiary)
            } else {
                ForEach(candidates, id: \.courseId) { summary in
                    courseSlider(for: summary)
                }
            }
        }
    }

    private func courseSlider(for summary: CourseGradeSummary) -> some View {
        let now = summary.nowPercent ?? 0
        let projected = vm.overrides[summary.courseId] ?? now
        let nowLetter = letterGrade(for: now, scale: summary.scale)
        let projLetter = letterGrade(for: projected, scale: summary.scale)
        let code = vm.codes[summary.courseId] ?? "Course"

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(code)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f → %.1f · %@ → %@", now, projected, nowLetter, projLetter))
                    .font(.mono(11, weight: .semibold))
                    .foregroundStyle(Color.accentHypothetical)
            }
            Slider(
                value: Binding(
                    get: { vm.overrides[summary.courseId] ?? now },
                    set: { vm.setOverride($0, for: summary.courseId) }
                ),
                in: 0...100,
                step: 1
            )
            .tint(Color.accentHypothetical)
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let projected = vm.projectedGPA.map { String(format: "%.2f", $0) } ?? "–.––"
        let current = vm.currentGPA.map { String(format: "%.2f", $0) } ?? "–.––"
        let lift = vm.lift
        let liftText = lift.map { String(format: "%@%.2f", $0 >= 0 ? "+" : "", $0) } ?? "–.––"

        return VStack(alignment: .leading, spacing: 6) {
            Text("Projected GPA")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            (Text(projected).font(.mono(22, weight: .bold)).foregroundStyle(Color.accentHypothetical)
                + Text("  ·  from \(current)  ·  \(liftText)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkTertiary))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.canvasBG, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.canvasHairline, lineWidth: 1))
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            vm.reset()
        } label: {
            Text("Reset")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(16)
    }
}
