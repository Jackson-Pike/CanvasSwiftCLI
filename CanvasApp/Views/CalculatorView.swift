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

// Placeholder — implemented in Task 9
struct SolveForMeTabView: View {
    @ObservedObject var vm: CalculatorViewModel
    var body: some View { Text("Solve For Me — coming in Task 9").padding() }
}
