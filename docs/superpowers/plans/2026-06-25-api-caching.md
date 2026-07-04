# API Caching — TTL Guard + AppState VM Lift

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent redundant Canvas API requests by adding TTL guards to both view models and lifting them into `AppState` so data survives navigation round-trips.

**Architecture:** Add a `lastFetchedAt: Date?` property and a `cacheTTL` constant to each view model; skip the network call when data is fresh. Move the view model instances from `@StateObject` on individual views into `AppState`, where they persist for the app session. Views switch from `@StateObject` to `@ObservedObject` and receive their VM from `AppState`.

**Tech Stack:** Swift 5.10, SwiftUI, `@MainActor`, `URLSession`/`APIClient` (custom). No new dependencies.

## Global Constraints

- Target: macOS 14+ (Sonoma)
- All view model work happens on `@MainActor`
- Manual refresh (toolbar button) must bypass the TTL — always fetch fresh data
- `CourseDetailViewModel` instances are keyed by `course.id: Int` in `AppState`
- No new files — modify existing files only

---

### Task 1: Add TTL guard to both view models

**Files:**
- Modify: `CanvasApp/ViewModels/CoursesViewModel.swift`
- Modify: `CanvasApp/ViewModels/CourseDetailViewModel.swift`

**Interfaces:**
- Produces: `CoursesViewModel.fetch(client:force:)` — `force: Bool = false`
- Produces: `CourseDetailViewModel.fetch(client:force:)` — `force: Bool = false`
- `force: true` bypasses TTL; `force: false` skips fetch when data is < 5 minutes old

- [ ] **Step 1: Update `CoursesViewModel.swift`**

Replace the entire file with:

```swift
import Foundation
import CanvasCore

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var enrollments: [Int: Enrollment] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    func fetch(client: APIClient, force: Bool = false) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           !courses.isEmpty {
            return
        }
        isLoading = true
        error = nil
        do {
            let fetched = try await client.courses()
            courses = fetched
            await withTaskGroup(of: (Int, Enrollment?).self) { group in
                for course in fetched {
                    group.addTask {
                        let e = try? await client.enrollments(courseId: course.id).first
                        return (course.id, e)
                    }
                }
                for await (id, enrollment) in group {
                    if let enrollment { self.enrollments[id] = enrollment }
                }
            }
            lastFetchedAt = Date()
        } catch let e as APIError {
            error = e.description
        } catch let e as DecodingError {
            switch e {
            case .keyNotFound(let key, let ctx):
                self.error = "Missing field '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let ctx):
                self.error = "Type mismatch (\(type)) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .valueNotFound(let type, let ctx):
                self.error = "Null value (\(type)) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted(let ctx):
                self.error = "Corrupted data at \(ctx.codingPath.map(\.stringValue).joined(separator: ".")): \(ctx.debugDescription)"
            @unknown default:
                self.error = e.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func currentScore(for courseId: Int) -> Double? {
        enrollments[courseId]?.grades?.currentScore
    }
}
```

- [ ] **Step 2: Update `CourseDetailViewModel.swift`**

Replace the entire file with:

```swift
import Foundation
import CanvasCore

@MainActor
final class CourseDetailViewModel: ObservableObject {
    let course: Course
    @Published var calculator: GradeCalculator?
    @Published var groupInfo: [Int: GroupInfo] = [:]
    @Published var allItems: [GradedItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    init(course: Course) { self.course = course }

    var gradingScale: [(String, Double)] { course.gradingScale }

    func fetch(client: APIClient, force: Bool = false) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           calculator != nil {
            return
        }
        isLoading = true
        error = nil
        do {
            async let groups = client.assignmentGroups(courseId: course.id)
            async let subs   = client.submissions(courseId: course.id)
            let (fetchedGroups, fetchedSubs) = try await (groups, subs)

            let info = Dictionary(uniqueKeysWithValues: fetchedGroups.map { g in
                (g.id, GroupInfo(name: g.name, weight: g.groupWeight,
                                 dropLowest:  g.rules?.dropLowest  ?? 0,
                                 dropHighest: g.rules?.dropHighest ?? 0,
                                 neverDrop:   Set(g.rules?.neverDrop ?? [])))
            })
            groupInfo = info
            let items = buildGradedItems(groups: fetchedGroups, submissions: fetchedSubs)
            allItems  = items
            calculator = GradeCalculator(items: items, groups: info,
                                          weighted: course.applyAssignmentGroupWeights ?? false,
                                          gradingScale: gradingScale)
            lastFetchedAt = Date()
        } catch let e as APIError { error = e.description }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
```

- [ ] **Step 3: Build to confirm no errors**

```bash
cd /Users/kahuku-air/Developer/CanvasCLISwift
xcodebuild -scheme CanvasApp -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no `error:` lines.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/ViewModels/CoursesViewModel.swift CanvasApp/ViewModels/CourseDetailViewModel.swift
git commit -m "feat: add 5-min TTL guard to CoursesViewModel and CourseDetailViewModel"
```

---

### Task 2: Lift view models into AppState; update views to use @ObservedObject

**Files:**
- Modify: `CanvasApp/App/AppState.swift`
- Modify: `CanvasApp/App/CanvasApp.swift`
- Modify: `CanvasApp/Views/CourseListView.swift`
- Modify: `CanvasApp/Views/CourseDetailView.swift`

**Interfaces:**
- Consumes: `CoursesViewModel.fetch(client:force:)` from Task 1
- Consumes: `CourseDetailViewModel.fetch(client:force:)` from Task 1
- Produces: `AppState.coursesVM: CoursesViewModel` — single shared instance
- Produces: `AppState.detailViewModel(for:) -> CourseDetailViewModel` — lazily creates + caches per course ID

- [ ] **Step 1: Update `AppState.swift`**

Replace the entire file with:

```swift
import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = KeychainHelper.load()
    @Published var showingSettings = false
    @Published var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")

    let coursesVM = CoursesViewModel()
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        var trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(token: trimmed)
        token = trimmed
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(token: token)
    }

    func detailViewModel(for course: Course) -> CourseDetailViewModel {
        if let existing = detailVMs[course.id] { return existing }
        let vm = CourseDetailViewModel(course: course)
        detailVMs[course.id] = vm
        return vm
    }
}
```

- [ ] **Step 2: Update `CanvasApp.swift` to pass `coursesVM` into `CourseListView`**

The `PopoverContent` body's `NavigationStack` block needs to pass the shared vm. Replace `PopoverContent.body`:

```swift
struct PopoverContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.hasSeenIntro {
            WelcomeView()
                .environmentObject(appState)
        } else if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
        } else {
            NavigationStack {
                CourseListView(vm: appState.coursesVM)
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
            }
        }
    }
}
```

- [ ] **Step 3: Update `CourseListView.swift`**

Switch from `@StateObject` to `@ObservedObject` received via init. Wire the refresh toolbar button to `force: true`. Replace the entire file:

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
                        Button("Retry") { Task { await refresh(force: true) } }
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
                        Button("Refresh") { Task { await refresh(force: true) } }
                            .buttonStyle(.bordered)
                    }
                )
            } else {
                List(vm.courses, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(
                        course: course,
                        vm: appState.detailViewModel(for: course)
                    )) {
                        CourseRowView(course: course, score: vm.currentScore(for: course.id),
                                      gradingScale: course.gradingScale)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await refresh(force: true) } } label: {
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
        .task { await refresh() }
    }

    private func refresh(force: Bool = false) async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client, force: force)
    }
}

struct CourseRowView: View {
    let course: Course
    let score: Double?
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.courseCode)
                    .font(.headline).foregroundStyle(.secondary)
                Text(course.name)
                    .font(.subheadline).foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            if let score {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline.monospacedDigit()).foregroundStyle(.primary)
                    let letter = letterGrade(for: score, scale: gradingScale)
                    Text(letter)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.letterGradeColor(letter), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 4: Update `CourseDetailView.swift`**

Switch from `@StateObject` to `@ObservedObject` received via init. Wire refresh to `force: true`. Replace the entire file:

```swift
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
```

- [ ] **Step 5: Build to confirm no errors**

```bash
cd /Users/kahuku-air/Developer/CanvasCLISwift
xcodebuild -scheme CanvasApp -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no `error:` lines.

- [ ] **Step 6: Commit**

```bash
git add CanvasApp/App/AppState.swift CanvasApp/App/CanvasApp.swift \
        CanvasApp/Views/CourseListView.swift CanvasApp/Views/CourseDetailView.swift
git commit -m "feat: lift CoursesViewModel and CourseDetailViewModel into AppState"
```
