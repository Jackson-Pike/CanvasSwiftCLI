# Course Filtering Design

**Date:** 2026-06-25

## Goal

Prevent non-student courses (teacher/TA roles) from ever appearing in the course list, and let students manually hide specific courses with that choice persisted across sessions.

---

## Feature 1: Automatic Teacher/TA Exclusion

### Approach

Add `enrollment_type[]=student` to the existing `/courses` API query in `APIClient.courses()`. Canvas applies the filter server-side, so only courses where the authenticated user holds a student enrollment are returned. No model changes, no client-side post-filtering, no extra data transferred.

### Change

**File:** `Sources/CanvasCore/APIClient.swift` — `courses()` method

Add one `URLQueryItem`:
```
URLQueryItem(name: "enrollment_type[]", value: "student")
```

---

## Feature 2: Manual Course Hiding

### Architecture

A new `HiddenCoursesStore` class owns all persistence of hidden course IDs. `CoursesViewModel` holds a reference to it and filters its published course list through it. `AppState` creates and vends both objects.

```
AppState
  ├── coursesVM: CoursesViewModel   (already exists)
  │     ├── allFetchedCourses: [Course]   (unfiltered, new)
  │     ├── courses: [Course]             (filtered, existing — now computed)
  │     └── hiddenStore: HiddenCoursesStore
  └── hiddenCoursesStore: HiddenCoursesStore   (new, shared with coursesVM)
```

### HiddenCoursesStore

New file: `CanvasApp/App/HiddenCoursesStore.swift`

- `@MainActor final class HiddenCoursesStore: ObservableObject`
- `@Published private(set) var hiddenIDs: Set<Int>`
- Reads/writes `UserDefaults` key `"hiddenCourseIDs"` (stored as `[Int]`)
- Public API:
  - `func hide(_ courseId: Int)`
  - `func restore(_ courseId: Int)`
  - `func isHidden(_ courseId: Int) -> Bool`

### CoursesViewModel changes

- Add `private var allFetchedCourses: [Course] = []` — raw list from API, never filtered directly
- `courses` stays `@Published var courses: [Course] = []` but is now always derived: after any fetch completes, and whenever `hiddenStore.hiddenIDs` changes, `courses` is recomputed as `allFetchedCourses.filter { !hiddenStore.isHidden($0.id) }`
- `init(hiddenStore: HiddenCoursesStore)` — store injected; `CoursesViewModel` subscribes to `hiddenStore.$hiddenIDs` via `AnyCancellable` in `init` and calls a private `applyFilter()` method on every emission
- `func applyFilter()` (private): `courses = allFetchedCourses.filter { !hiddenStore.isHidden($0.id) }`

### AppState changes

- Add `let hiddenCoursesStore = HiddenCoursesStore()`
- Change `coursesVM` init to `CoursesViewModel(hiddenStore: hiddenCoursesStore)`

### CourseListView changes

- Add `.swipeActions(edge: .trailing)` on each course row's `NavigationLink`
- Single action: label "Hide", system image `eye.slash`, `.destructive` role
- On tap: `appState.hiddenCoursesStore.hide(course.id)`
- No confirmation required — restore is easy via Settings

### SettingsView changes

- Read `appState.hiddenCoursesStore` via `@EnvironmentObject`
- Add a "Hidden Courses" section at the bottom of the settings form
- Section only rendered when `hiddenCoursesStore.hiddenIDs` is non-empty
- Each row: course name (looked up from `appState.coursesVM.allFetchedCourses`) + "Restore" button
- "Restore" calls `hiddenCoursesStore.restore(courseId)`
- If all courses are restored, section disappears automatically

---

## Data Persistence

| Key | Type | Location |
|-----|------|----------|
| `"hiddenCourseIDs"` | `[Int]` | `UserDefaults.standard` |

---

## Error / Edge Cases

- **User hides all courses:** List shows `ContentUnavailableView` ("No Active Courses") with the existing empty-state view. The Retry/Refresh button still works. The Settings sheet still shows hidden courses for restore.
- **Hidden course no longer exists in API response:** `allFetchedCourses` won't contain it; the Settings section won't display a name for it. Stale IDs in `hiddenIDs` are harmless — they simply never match.
- **Course restored before next fetch:** `hiddenStore.restore()` publishes a change → `courses` computed property re-evaluates → course reappears instantly without a network call.

---

## Files Touched

| File | Change |
|------|--------|
| `Sources/CanvasCore/APIClient.swift` | Add `enrollment_type[]=student` query param |
| `CanvasApp/App/HiddenCoursesStore.swift` | **New** — persistence + observable store |
| `CanvasApp/App/AppState.swift` | Add `hiddenCoursesStore`, update `coursesVM` init |
| `CanvasApp/ViewModels/CoursesViewModel.swift` | Add `allFetchedCourses`, computed `courses`, injected store |
| `CanvasApp/Views/CourseListView.swift` | Add swipe-to-hide action |
| `CanvasApp/Views/SettingsView.swift` | Add "Hidden Courses" restore section |
