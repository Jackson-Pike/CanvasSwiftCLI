import SwiftUI
import CanvasCore

struct CalculatorView: View {
    @StateObject private var vm: CalculatorViewModel
    @State private var selectedTab = 0

    init(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)]) {
        _vm = StateObject(wrappedValue: CalculatorViewModel(
            course: course, items: items, groupInfo: groupInfo, gradingScale: gradingScale))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Live grade header
            HStack {
                Text("Live Grade:")
                Spacer()
                if let grade = vm.liveGrade {
                    Text(String(format: "%.1f%%", grade))
                        .font(.title2.bold()).foregroundStyle(Color.byuhGold)
                    Text(letterGrade(for: grade, scale: vm.gradingScale))
                        .font(.title2.bold())
                        .foregroundStyle(Color.letterGradeColor(letterGrade(for: grade, scale: vm.gradingScale)))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Picker("Mode", selection: $selectedTab) {
                Text("What-If").tag(0)
                Text("Solve For Me").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                WhatIfTabView(vm: vm)
            } else {
                SolveForMeTabView(vm: vm)
            }
        }
        .navigationTitle("Calculator")
    }
}

struct WhatIfTabView: View {
    @ObservedObject var vm: CalculatorViewModel

    var body: some View {
        List(vm.baseItems, id: \.assignmentId) { item in
            WhatIfRowView(item: item, vm: vm)
        }
        .listStyle(.plain)
    }
}

struct WhatIfRowView: View {
    let item: GradedItem
    @ObservedObject var vm: CalculatorViewModel
    @FocusState private var focused: Bool

    private var binding: Binding<CalculatorViewModel.WhatIfEntry> {
        Binding(
            get: { vm.whatIfEntries[item.assignmentId] ?? CalculatorViewModel.WhatIfEntry() },
            set: { vm.whatIfEntries[item.assignmentId] = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("", isOn: binding.isActive)
                    .labelsHidden()
                Text(item.name).lineLimit(1)
                Spacer()
                // Original score
                if let earned = item.earnedPoints {
                    Text(String(format: "%.0f/%.0f", earned, item.pointsPossible))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(String(format: "—/%.0f", item.pointsPossible))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if binding.isActive.wrappedValue {
                HStack(spacing: 8) {
                    TextField("Score", text: binding.inputText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .focused($focused)
                    Picker("", selection: binding.inputMode) {
                        Text("%").tag(CalculatorViewModel.WhatIfEntry.InputMode.percent)
                        Text("pts").tag(CalculatorViewModel.WhatIfEntry.InputMode.points)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    Spacer()
                    if let pct = binding.wrappedValue.resolvedPercent(possiblePoints: item.pointsPossible) {
                        let letter = letterGrade(for: pct, scale: vm.gradingScale)
                        Text(letter).font(.caption.bold())
                            .foregroundStyle(Color.letterGradeColor(letter))
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
        .onAppear { focused = false }
    }
}

struct SolveForMeTabView: View {
    @ObservedObject var vm: CalculatorViewModel

    private var gradeLetters: [String] {
        vm.gradingScale.map { $0.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Target grade input ──────────────────────────
                GroupBox("Target Grade") {
                    Picker("Input mode", selection: $vm.targetMode) {
                        Text("Letter").tag(CalculatorViewModel.TargetMode.letter)
                        Text("Percent").tag(CalculatorViewModel.TargetMode.percent)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if vm.targetMode == .letter {
                        Picker("Grade", selection: $vm.targetLetter) {
                            ForEach(gradeLetters, id: \.self) { letter in
                                Text(letter).tag(letter)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        HStack {
                            TextField("90", text: $vm.targetPercentInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("%")
                        }
                    }
                }

                // ── Assignment scope ────────────────────────────
                GroupBox("Which assignments?") {
                    Picker("Scope", selection: $vm.solveScope) {
                        Text("Single assignment").tag(CalculatorViewModel.SolveScope.single)
                        Text("Spread across selected").tag(CalculatorViewModel.SolveScope.spread)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if vm.solveScope == .single {
                        if vm.ungradedItems.isEmpty {
                            Text("No ungraded assignments.").foregroundStyle(.secondary)
                        } else {
                            Picker("Assignment", selection: $vm.solveSingleId) {
                                Text("Select…").tag(nil as Int?)
                                ForEach(vm.ungradedItems, id: \.assignmentId) { item in
                                    Text(item.name).tag(item.assignmentId as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.ungradedItems, id: \.assignmentId) { item in
                                Toggle(item.name, isOn: Binding(
                                    get: { vm.solveMultiIds.contains(item.assignmentId) },
                                    set: { on in
                                        if on { vm.solveMultiIds.insert(item.assignmentId) }
                                        else  { vm.solveMultiIds.remove(item.assignmentId) }
                                    }
                                ))
                                .font(.subheadline)
                            }
                        }
                    }
                }

                // ── Result ──────────────────────────────────────
                GroupBox("Result") {
                    SolveResultView(vm: vm)
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct SolveResultView: View {
    @ObservedObject var vm: CalculatorViewModel

    var body: some View {
        Group {
            if vm.solveAssignmentIds.isEmpty {
                Text("Select an assignment above.")
                    .foregroundStyle(.secondary)
            } else if let result = vm.solveResult {
                switch result {
                case .alreadyAchieved:
                    Label("You've already hit your target grade!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                case .needed(let percent):
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You need:").font(.subheadline).foregroundStyle(.secondary)
                        if vm.solveScope == .single, let id = vm.solveSingleId,
                           let item = vm.baseItems.first(where: { $0.assignmentId == id }) {
                            let pts = item.pointsPossible * percent / 100
                            Text(String(format: "**%.1f%%** (%.0f / %.0f pts) on %@",
                                        percent, pts, item.pointsPossible, item.name))
                                .font(.headline)
                        } else {
                            let n = vm.solveAssignmentIds.count
                            Text(String(format: "**%.1f%%** on each of your %d selected assignments", percent, n))
                                .font(.headline)
                        }
                        Text(String(format: "Target: %.1f%%  (%@)",
                                    vm.targetPercentValue,
                                    vm.targetMode == .letter ? vm.targetLetter : "\(vm.targetPercentInput)%"))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                case .impossible(let maxPossible):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Not achievable", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red).font(.headline)
                        Text(String(format: "Even 100%% on selected assignments gives you %.1f%%.", maxPossible))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
