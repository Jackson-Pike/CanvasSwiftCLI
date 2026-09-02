import SwiftUI
import CanvasCore

/// Course-scope What-If Sandbox rail (spec §2 "Course workspace + Sandbox").
/// Docked permanently into `GradesTabView` (replacing the old `.inspector` calculator),
/// this rail and the main grades column share a single `CalculatorViewModel` instance so
/// a slider drag here updates the headline/groups/assignments over there too.
public struct SandboxRailView: View {
    @ObservedObject var vm: CalculatorViewModel

    public init(vm: CalculatorViewModel) {
        self.vm = vm
    }

    /// The item the current `.needed` solve is targeting — used to place the green marker
    /// on the matching `HypotheticalSlider`. Defaults to `solveSingleId` (the VM seeds this
    /// to the first ungraded item on init).
    private var requiredItemId: Int? { vm.solveSingleId }

    private var requiredPercent: Double? {
        guard case .needed(let percent) = vm.solveResult else { return nil }
        return percent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.canvasHairline)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    targetSection
                    hypotheticalsSection
                    scenariosSection
                }
                .padding(16)
            }
            Divider().overlay(Color.canvasHairline)
            footer
        }
        .frame(width: 330)
        .background(Color.canvasPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.canvasHairline).frame(width: 1)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sandbox")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            Text("Drag any ungraded item. Nothing here is sent to Canvas.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(16)
    }

    // MARK: - Target block

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I Want to Finish With")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            TargetChips(vm: vm)
            answerSentence
        }
    }

    @ViewBuilder
    private var answerSentence: some View {
        if let result = vm.solveResult {
            Group {
                switch result {
                case .needed(let percent):
                    (Text("Score ")
                        + Text("\(Int(percent.rounded()))%").foregroundStyle(Color.accentHypothetical).bold()
                        + Text(" or better on the remaining work and ")
                        + targetPhrase
                        + Text("."))
                case .alreadyAchieved:
                    Text("You've already locked this in.")
                case .impossible(let maxPossible):
                    Text("Out of reach — the best you can finish is \(Int(maxPossible.rounded()))%.")
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Color.inkPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Trailing clause of the `.needed` answer sentence, branched on `targetMode` so it
    /// names the target the user actually picked (letter chip vs. the "90%" chip) — in
    /// `.percent` mode `targetLetter` is stale (defaults to "A") and must not be used.
    private var targetPhrase: Text {
        switch vm.targetMode {
        case .letter:
            return Text("you land an ") + Text(vm.targetLetter).bold()
        case .percent:
            return Text("you hit ") + Text("\(vm.targetPercentInput)%").bold()
        }
    }

    // MARK: - Hypotheticals

    private var hypotheticalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hypotheticals")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            if vm.ungradedItems.isEmpty {
                Text("No ungraded items yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkTertiary)
            } else {
                ForEach(vm.ungradedItems, id: \.assignmentId) { item in
                    HypotheticalSlider(
                        label: item.name,
                        value: sliderBinding(for: item),
                        requiredPercent: requiredItemId == item.assignmentId ? requiredPercent : nil
                    )
                }
            }
        }
    }

    private func sliderBinding(for item: GradedItem) -> Binding<Double> {
        Binding(
            get: {
                vm.whatIfEntries[item.assignmentId]?.resolvedPercent(possiblePoints: item.pointsPossible) ?? 0
            },
            set: { newValue in
                var entry = vm.whatIfEntries[item.assignmentId] ?? CalculatorViewModel.WhatIfEntry()
                entry.isActive = true
                entry.inputMode = .percent
                entry.inputText = String(Int(newValue.rounded()))
                vm.whatIfEntries[item.assignmentId] = entry
            }
        )
    }

    // MARK: - Scenarios

    private var scenariosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenarios")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            ScenarioChips(vm: vm)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                // TODO Phase 1a: persistence deferred
            } label: {
                Text("Save scenario")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentHypothetical)

            Button {
                // TODO Phase 1a: persistence deferred
            } label: {
                Text("Pin to menu bar")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
    }
}

// MARK: - TargetChips

public struct TargetChips: View {
    @ObservedObject var vm: CalculatorViewModel

    public init(vm: CalculatorViewModel) {
        self.vm = vm
    }

    private let letterOptions = ["A-", "A", "B+"]

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(letterOptions, id: \.self) { letter in
                chip(label: letter, selected: vm.targetMode == .letter && vm.targetLetter == letter) {
                    vm.targetMode = .letter
                    vm.targetLetter = letter
                }
            }
            chip(label: "90%", selected: vm.targetMode == .percent && vm.targetPercentInput == "90") {
                vm.targetMode = .percent
                vm.targetPercentInput = "90"
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
                .background(
                    Capsule().fill(selected ? Color.accentHypothetical : Color.canvasBG)
                )
                .overlay(
                    Capsule().stroke(Color.canvasHairlineStrong, lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HypotheticalSlider

public struct HypotheticalSlider: View {
    let label: String
    @Binding var value: Double
    let requiredPercent: Double?

    public init(label: String, value: Binding<Double>, requiredPercent: Double? = nil) {
        self.label = label
        self._value = value
        self.requiredPercent = requiredPercent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .font(.mono(12.5, weight: .semibold))
                    .foregroundStyle(Color.accentHypothetical)
            }
            ZStack(alignment: .leading) {
                Slider(value: $value, in: 0...100, step: 1)
                    .tint(Color.accentHypothetical)
                if let requiredPercent {
                    GeometryReader { geo in
                        let x = geo.size.width * CGFloat(requiredPercent / 100)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2, height: 16)
                            .position(x: x, y: geo.size.height / 2)
                    }
                    .frame(height: 20)
                    .allowsHitTesting(false)
                }
            }
            if let requiredPercent {
                Text("green line = the \(Int(requiredPercent.rounded()))% you need")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.green)
            }
        }
    }
}

// MARK: - ScenarioChips

public struct ScenarioChips: View {
    @ObservedObject var vm: CalculatorViewModel

    public init(vm: CalculatorViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            scenarioButton(title: "Everything 100%", hint: projectedHint(percent: 100)) {
                applyBlanket(percent: 100)
            }
            scenarioButton(title: "Keep my average", hint: projectedHint(percent: actualPercent)) {
                applyBlanket(percent: actualPercent)
            }
            scenarioButton(title: "Bomb the final", hint: projectedHint(percent: 50)) {
                applyBlanket(percent: 50)
            }
        }
    }

    private var actualPercent: Double {
        GradeCalculator(items: vm.baseItems, groups: vm.groupInfo,
                        weighted: vm.weighted, gradingScale: vm.gradingScale).currentGrade() ?? 0
    }

    private func projectedHint(percent: Double) -> String {
        let items = vm.baseItems.applyingBlanketToUngraded(percent: percent)
        let calc = GradeCalculator(items: items, groups: vm.groupInfo,
                                   weighted: vm.weighted, gradingScale: vm.gradingScale)
        guard let grade = calc.currentGrade() else { return "" }
        let letter = calc.letterGradeForPercent(grade)
        return String(format: "%.1f %@", grade, letter)
    }

    private func applyBlanket(percent: Double) {
        for item in vm.ungradedItems {
            var entry = vm.whatIfEntries[item.assignmentId] ?? CalculatorViewModel.WhatIfEntry()
            entry.isActive = true
            entry.inputMode = .percent
            entry.inputText = String(Int(percent.rounded()))
            vm.whatIfEntries[item.assignmentId] = entry
        }
    }

    private func scenarioButton(title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if !hint.isEmpty {
                    Text(hint)
                        .font(.mono(11, weight: .regular))
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.canvasBG, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("SandboxRail - Light") {
    let items = [
        GradedItem(assignmentId: 1, name: "HW 1", groupId: 1, pointsPossible: 100, earnedPoints: 92),
        GradedItem(assignmentId: 2, name: "HW 2", groupId: 1, pointsPossible: 100, earnedPoints: nil),
        GradedItem(assignmentId: 3, name: "Final Exam", groupId: 2, pointsPossible: 100, earnedPoints: nil)
    ]
    let groups: [Int: GroupInfo] = [
        1: GroupInfo(name: "Homework", weight: 40),
        2: GroupInfo(name: "Exams", weight: 60)
    ]
    let vm = CalculatorViewModel(items: items, groupInfo: groups, gradingScale: byuhDefaultScale, weighted: true)
    vm.targetMode = .letter
    vm.targetLetter = "A-"
    return SandboxRailView(vm: vm)
        .preferredColorScheme(.light)
}

#Preview("SandboxRail - Dark, needed") {
    let items = [
        GradedItem(assignmentId: 1, name: "HW 1", groupId: 1, pointsPossible: 100, earnedPoints: 92),
        GradedItem(assignmentId: 2, name: "HW 2", groupId: 1, pointsPossible: 100, earnedPoints: nil),
        GradedItem(assignmentId: 3, name: "Final Exam", groupId: 2, pointsPossible: 100, earnedPoints: nil)
    ]
    let groups: [Int: GroupInfo] = [
        1: GroupInfo(name: "Homework", weight: 40),
        2: GroupInfo(name: "Exams", weight: 60)
    ]
    let vm = CalculatorViewModel(items: items, groupInfo: groups, gradingScale: byuhDefaultScale, weighted: true)
    vm.targetMode = .letter
    vm.targetLetter = "A"
    return SandboxRailView(vm: vm)
        .preferredColorScheme(.dark)
}
