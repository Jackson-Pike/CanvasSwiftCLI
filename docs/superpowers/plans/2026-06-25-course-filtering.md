# Course Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically exclude teacher/TA-role courses from the course list, and let students swipe to hide specific courses with that choice persisted and reversible from Settings.

**Architecture:** `APIClient.courses()` gains an `enrollment_type[]=student` query param (server-side filter). A new `HiddenCoursesStore` owns a `Set<Int>` of hidden course IDs in `UserDefaults`. `CoursesViewModel` is given the store at init, keeps a raw `allFetchedCourses` list, and re-publishes a filtered `courses` array whenever either the raw list or the store changes. `AppState` wires the two together. `CourseListView` exposes a swipe-to-hide action; `SettingsView` shows a restore panel.

**Tech Stack:** Swift 5.10, SwiftUI, Combine (`AnyCancellable`), `UserDefaults`, `URLSession`/`APIClient` (custom). No new dependencies.

## Global Constraints

- macOS 14+ (Sonoma)
- All `ObservableObject` work on `@MainActor`
- No new Swift Package dependencies
- `UserDefaults` key for hidden IDs: `"hiddenCourseIDs"` (stored as `[Int]`)

---

## File Map

| File | Change |
|------|--------|
| `Sources/CanvasCore/APIClient.swift` | Add `enrollment_type[]=student` query param to `courses()` |
| `CanvasApp/App/HiddenCoursesStore.swift` | **New** — `@MainActor ObservableObject`, persistence, `hide`/`restore`/`isHidden` |
| `CanvasApp/ViewModels/CoursesViewModel.swift` | Accept `HiddenCoursesStore` in init; add `allFetchedCourses`; subscribe + filter |
| `CanvasApp/App/AppState.swift` | Add `hiddenCoursesStore`; wire into `coursesVM` via `init()` |
| `CanvasApp/Views/CourseListView.swift` | Add `.swipeActions` hide button |
| `CanvasApp/Views/SettingsView.swift` | Add "Hidden Courses" restore section |
| `CanvasApp/App/CanvasApp.swift` | Inject `hiddenCoursesStore` as environment object into `SettingsView` |

---

### Task 1: Add enrollment_type filter to APIClient

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`

**Interfaces:**
- Produces: `APIClient.courses()` now only returns courses where the authenticated user is a student

- [ ] **Step 1: Add the query param**

In `Sources/CanvasCore/APIClient.swift`, replace the `courses()` method:

```swift
public func courses() async throws -> [Course] {
    let data = try await get("/courses", query: [
        URLQueryItem(name: "enrollment_state", value: "active"),
        URLQueryItem(name: "enrollment_type[]", value: "student"),
        URLQueryItem(name: "per_page", value: "50"),
        URLQueryItem(name: "include[]", value: "grading_scheme")
    ])
    return try decoder().decode([Course].self, from: data)
}
```

- [ ] **Step 2: Build to verify**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift
git commit -m "feat: filter Canvas courses to student enrollments only"
```

---

### Task 2: Create HiddenCoursesStore

**Files:**
- Create: `CanvasApp/App/HiddenCoursesStore.swift`

**Interfaces:**
- Produces: `HiddenCoursesStore` — `@MainActor final class`, `ObservableObject`
  - `@Published private(set) var hiddenIDs: Set<Int>`
  - `func hide(_ courseId: Int)`
  - `func restore(_ courseId: Int)`
  - `func isHidden(_ courseId: Int) -> Bool`

- [ ] **Step 1: Create the file**

Create `CanvasApp/App/HiddenCoursesStore.swift`:

```swift
import Foundation

@MainActor
final class HiddenCoursesStore: ObservableObject {
    @Published private(set) var hiddenIDs: Set<Int>

    private let defaultsKey = "hiddenCourseIDs"

    init() {
        let saved = UserDefaults.standard.array(forKey: "hiddenCourseIDs") as? [Int] ?? []
        hiddenIDs = Set(saved)
    }

    func hide(_ courseId: Int) {
        hiddenIDs.insert(courseId)
        persist()
    }

    func restore(_ courseId: Int) {
        hiddenIDs.remove(courseId)
        persist()
    }

    func isHidden(_ courseId: Int) -> Bool {
        hiddenIDs.contains(courseId)
    }

    private func persist() {
        UserDefaults.standard.set(Array(hiddenIDs), forKey: defaultsKey)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/App/HiddenCoursesStore.swift
git commit -m "feat: add HiddenCoursesStore with UserDefaults persistence"
```

---

### Task 3: Update CoursesViewModel and AppState

**Files:**
- Modify: `CanvasApp/ViewModels/CoursesViewModel.swift`
- Modify: `CanvasApp/App/AppState.swift`

**Interfaces:**
- Consumes: `HiddenCoursesStore` from Task 2
- Produces:
  - `CoursesViewModel.init(hiddenStore: HiddenCoursesStore)`
  - `CoursesViewModel.allFetchedCourses: [Course]` (internal read, only VM writes)
  - `AppState.hiddenCoursesStore: HiddenCoursesStore`
  - `AppState.init()` — creates store, passes to `coursesVM`

- [ ] **Step 1: Replace CoursesViewModel.swift**

```swift
import Foundation
import Combine
import CanvasCore

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var enrollments: [Int: Enrollment] = [:]
    @Published var isLoading = false
    @Published var error: String?

    private(set) var allFetchedCourses: [Course] = []
    private let hiddenStore: HiddenCoursesStore
    private var cancellable: AnyCancellable?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    init(hiddenStore: HiddenCoursesStore) {
        self.hiddenStore = hiddenStore
        cancellable = hiddenStore.$hiddenIDs.sink { [weak self] _ in
            self?.applyFilter()
        }
    }

    private func applyFilter() {
        courses = allFetchedCourses.filter { !hiddenStore.isHidden($0.id) }
    }

    func fetch(client: APIClient, force: Bool = false) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           !allFetchedCourses.isEmpty {
            return
        }
        isLoading = true
        error = nil
        do {
            let fetched = try await client.courses()
            allFetchedCourses = fetched
            applyFilter()
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

- [ ] **Step 2: Replace AppState.swift**

`AppState` needs an explicit `init()` so it can create `HiddenCoursesStore` first and pass it into `CoursesViewModel`. Properties with inline default expressions (`KeychainHelper.load()`, `UserDefaults...`) still work — Swift evaluates them before running `init()`.

```swift
import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = KeychainHelper.load()
    @Published var showingSettings = false
    @Published var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")

    let hiddenCoursesStore: HiddenCoursesStore
    let coursesVM: CoursesViewModel
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    init() {
        let store = HiddenCoursesStore()
        hiddenCoursesStore = store
        coursesVM = CoursesViewModel(hiddenStore: store)
    }

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

- [ ] **Step 3: Build to verify**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/ViewModels/CoursesViewModel.swift CanvasApp/App/AppState.swift
git commit -m "feat: wire HiddenCoursesStore into CoursesViewModel and AppState"
```

---

### Task 4: Add swipe-to-hide in CourseListView

**Files:**
- Modify: `CanvasApp/Views/CourseListView.swift`

**Interfaces:**
- Consumes: `AppState.hiddenCoursesStore.hide(_ courseId: Int)` from Task 2/3

- [ ] **Step 1: Add .swipeActions to the NavigationLink row**

In `CourseListView.swift`, find the `List` block and replace it:

```swift
List(vm.courses, id: \.id) { course in
    NavigationLink(destination: CourseDetailView(
        course: course,
        vm: appState.detailViewModel(for: course)
    )) {
        CourseRowView(course: course, score: vm.currentScore(for: course.id),
                      gradingScale: course.gradingScale)
    }
    .swipeActions(edge: .trailing) {
        Button(role: .destructive) {
            appState.hiddenCoursesStore.hide(course.id)
        } label: {
            Label("Hide", systemImage: "eye.slash")
        }
    }
}
.listStyle(.plain)
```

- [ ] **Step 2: Build to verify**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/Views/CourseListView.swift
git commit -m "feat: add swipe-to-hide on course list rows"
```

---

### Task 5: Add Hidden Courses restore section in SettingsView

**Files:**
- Modify: `CanvasApp/Views/SettingsView.swift`
- Modify: `CanvasApp/App/CanvasApp.swift`

**Interfaces:**
- Consumes: `HiddenCoursesStore.hiddenIDs`, `HiddenCoursesStore.restore(_ courseId: Int)` from Task 2
- Consumes: `CoursesViewModel.allFetchedCourses: [Course]` from Task 3

- [ ] **Step 1: Replace SettingsView.swift**

`SettingsView` gains `@EnvironmentObject var hiddenStore: HiddenCoursesStore`. The "Hidden Courses" section is rendered only when `hiddenStore.hiddenIDs` is non-empty. Course names are looked up from `appState.coursesVM.allFetchedCourses`; if a course ID has no match (e.g. was dropped by the API), it falls back to "Course {id}".

```swift
import SwiftUI

struct SettingsView: View {
    let isOnboarding: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hiddenStore: HiddenCoursesStore
    @State private var tokenInput = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(isOnboarding ? "Welcome to Canvas" : "Settings")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Canvas API Token")
                    .font(.subheadline).foregroundStyle(.secondary)
                SecureField("Paste token here…", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                Text("Find this in Canvas → Account → Settings → New Access Token")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Button("Save") {
                appState.saveToken(tokenInput)
                if !isOnboarding { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.byuhRed)
            .disabled(tokenInput.isEmpty)

            if !hiddenStore.hiddenIDs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hidden Courses")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(Array(hiddenStore.hiddenIDs).sorted(), id: \.self) { courseId in
                        HStack {
                            let name = appState.coursesVM.allFetchedCourses
                                .first { $0.id == courseId }?.courseCode
                                ?? "Course \(courseId)"
                            Text(name).font(.subheadline)
                            Spacer()
                            Button("Restore") { hiddenStore.restore(courseId) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
```

- [ ] **Step 2: Inject hiddenCoursesStore into SettingsView in CanvasApp.swift**

`SettingsView` is shown in two places inside `PopoverContent`: the onboarding branch and the settings sheet. Both need the `hiddenCoursesStore` environment object. Replace `CanvasApp.swift`:

```swift
import SwiftUI
import CanvasCore

@main
struct CanvasApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environmentObject(appState)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PopoverContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.hasSeenIntro {
            WelcomeView()
                .environmentObject(appState)
        } else if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
                .environmentObject(appState.hiddenCoursesStore)
        } else {
            NavigationStack {
                CourseListView(vm: appState.coursesVM)
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
                    .environmentObject(appState.hiddenCoursesStore)
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/Views/SettingsView.swift CanvasApp/App/CanvasApp.swift
git commit -m "feat: add Hidden Courses restore section to Settings"
```
