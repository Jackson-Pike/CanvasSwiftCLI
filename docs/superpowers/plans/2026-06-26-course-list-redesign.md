# Course List Billboard Card Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the compact plain-list rows with full-width billboard cards — course name large on the left, soft-tinted grade slab with a large letter grade on the right.

**Architecture:** Rewrite `CourseRowView` → `CourseCardView` as a self-contained card view. Update the `List` in `CourseListView` to use clear row backgrounds and hidden separators so the card's own `RoundedRectangle` background is the visible chrome. Swipe-to-hide is preserved via a `ZStack` + hidden `NavigationLink` pattern that suppresses the automatic chevron.

**Tech Stack:** SwiftUI, iOS 16+, no new dependencies.

## Global Constraints

- Swift tools version 5.9, platform macOS 14 (iOS migration pending — match existing targets)
- No new package dependencies
- All existing XCTest tests must continue to pass
- Swipe-to-hide (`.swipeActions`) must remain functional
- No model or ViewModel changes

---

### Task 1: Rewrite `CourseCardView` and update `CourseListView`

**Files:**
- Modify: `CanvasApp/Views/CourseListView.swift`

**Interfaces:**
- Consumes: `Course.name`, `Course.courseCode`, `score: Double?`, `gradingScale: [(String, Double)]`, `Color.letterGradeColor(_:)` from `BrandColors.swift`, `letterGrade(for:scale:)` (existing free function in scope)
- Produces: `CourseCardView` struct (replaces `CourseRowView`)

---

- [ ] **Step 1: Replace the entire contents of `CourseListView.swift`**

Replace the full file with the implementation below. Key changes from the current file:

1. `CourseRowView` is renamed `CourseCardView` and fully rewritten
2. `List` rows use `.listRowBackground(Color.clear)` + `.listRowSeparator(.hidden)` + custom insets
3. `NavigationLink` uses the hidden-label trick (`EmptyView()` at `.opacity(0)`) to suppress the automatic disclosure chevron — the card sits on top with `.allowsHitTesting(false)` so taps fall through to the link
4. The `List` background is set to `Color(.systemGroupedBackground)` via `.scrollContentBackground(.hidden)` + `.background`

```swift
import SwiftUI
import CanvasCore

struct CourseListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: CoursesViewModel

    var body: some View {
        Group {
            if vm.isLoading {
                Color.clear.overlay(ProgressView("Loading courses…"))
            } else if let error = vm.error {
                Color.clear.overlay(
                    ContentUnavailableView {
                        Label("Couldn't Load Courses", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { refresh(force: true) }
                            .buttonStyle(.bordered)
                        if error.contains("Invalid token") || error.contains("unauthorized") {
                            Button("Update Token…") { appState.showingSettings = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.byuhRed)
                        }
                    }
                )
            } else if vm.courses.isEmpty {
                Color.clear.overlay(
                    ContentUnavailableView {
                        Label("No Active Courses", systemImage: "graduationcap")
                    } description: {
                        Text("Courses you're enrolled in this term will appear here.")
                    } actions: {
                        Button("Refresh") { refresh(force: true) }
                            .buttonStyle(.bordered)
                    }
                )
            } else {
                List(vm.courses, id: \.id) { course in
                    ZStack(alignment: .leading) {
                        NavigationLink(destination: CourseDetailView(
                            course: course,
                            vm: appState.detailViewModel(for: course)
                        )) { EmptyView() }
                        .opacity(0)

                        CourseCardView(
                            course: course,
                            score: vm.currentScore(for: course.id),
                            gradingScale: course.gradingScale
                        )
                        .allowsHitTesting(false)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            appState.hiddenCoursesStore.hide(course.id)
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { refresh(force: true) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
                .accessibilityLabel("Refresh courses")
                .help("Refresh courses")
            }
            ToolbarItem(placement: .automatic) {
                Button { appState.showingSettings = true } label: {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Settings")
                .help("Settings")
            }
        }
        .task { refresh() }
    }

    private func refresh(force: Bool = false) {
        guard let client = appState.makeClient() else { return }
        vm.fetch(client: client, force: force)
    }
}

struct CourseCardView: View {
    let course: Course
    let score: Double?
    let gradingScale: [(String, Double)]

    private var letter: String {
        score.map { letterGrade(for: $0, scale: gradingScale) } ?? "—"
    }

    private var gradeColor: Color {
        guard score != nil else { return Color(.secondaryLabel) }
        return Color.letterGradeColor(letter)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(course.courseCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let score {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                gradeColor.opacity(0.15)
                Text(letter)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(gradeColor)
            }
            .frame(width: 90)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
```

- [ ] **Step 2: Build to verify no compile errors**

```bash
cd /Users/kahuku-air/Developer/CanvasCLISwift
swift build 2>&1 | tail -20
```

Expected: `Build complete!` with no errors. If `CourseRowView` is referenced anywhere else, the compiler will flag it — fix those references by updating to `CourseCardView`.

- [ ] **Step 3: Run existing tests to confirm nothing regressed**

```bash
swift test 2>&1 | tail -20
```

Expected: All existing tests pass (`ModelsTests`, `GradeCalculatorTests`, `SolverTests`, `APIClientPaginationTests`).

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/Views/CourseListView.swift
git commit -m "feat: redesign course list with billboard grade cards

Replace compact list rows with full-width cards. Course nickname is
large on the left; a 90pt slab on the right shows the letter grade
(44pt bold) over a soft tint of the grade color. Swipe-to-hide
preserved via hidden NavigationLink pattern."
```
