# Instructor Messaging — Design Spec

**Date:** 2026-06-26  
**Scope:** macOS only (iOS deferred)

## Overview

A mail icon button in the `CourseDetailView` toolbar lets students compose and send a Canvas Conversation message directly to the course instructor(s). The sheet presents subject and body fields; on send the message is delivered via the Canvas Conversations API.

---

## Data Layer

### `APIClient` additions

**`courseTeachers(courseId: Int) async throws -> [Int]`**

```
GET /api/v1/courses/{courseId}/enrollments
  ?type[]=TeacherEnrollment
  &per_page=50
```

Returns an array of instructor user IDs (typically one). Decodes a minimal `TeacherEnrollment` struct (just `userId: Int`) and extracts the IDs. Uses the existing `getPaginated` helper.

**`sendConversation(recipientIds: [Int], subject: String, body: String) async throws`**

```
POST /api/v1/conversations
```

Body (form-encoded or JSON):
- `recipients[]` — one entry per recipient ID (as string)
- `subject`
- `body`
- `group_conversation=false`

Expects HTTP 201. Any non-2xx throws `APIError.http(_)`. No response body is parsed.

### `CourseDetailViewModel` change

Adds `@Published var instructorIds: [Int] = []`.

In `fetch(client:force:)`, the teacher call runs in parallel with the existing `assignmentGroups` and `submissions` fetches via `async let`:

```swift
async let teachers = client.courseTeachers(courseId: course.id)
async let groups   = client.assignmentGroups(courseId: course.id)
async let subs     = client.submissions(courseId: course.id)
```

If `teachers` throws, the error is silently swallowed and `instructorIds` stays `[]` — the mail button is hidden rather than blocking grade load.

---

## Compose ViewModel

**File:** `CanvasApp/ViewModels/ComposeMessageViewModel.swift`

`@MainActor final class ComposeMessageViewModel: ObservableObject`

| Property | Type | Notes |
|---|---|---|
| `subject` | `@Published String` | Starts empty |
| `body` | `@Published String` | Starts empty |
| `isSending` | `@Published Bool` | `false` |
| `sendError` | `@Published String?` | `nil` |
| `didSend` | `@Published Bool` | `false` — sheet dismisses when `true` |

**`send(client: APIClient, recipientIds: [Int]) async`**

1. Guard: body must be non-empty (Send button is also disabled in UI, so this is a safety net).
2. Set `isSending = true`, clear `sendError`.
3. Call `client.sendConversation(recipientIds:subject:body:)`.
4. On success: set `didSend = true`.
5. On failure: set `sendError = error.localizedDescription`, set `isSending = false`.

---

## UI

### Toolbar button — `CourseDetailView`

Add `@State private var showingCompose = false` to `CourseDetailView`.

In the view's `.toolbar`:

```swift
if !vm.instructorIds.isEmpty {
    Button { showingCompose = true } label: {
        Label("Message Instructor", systemImage: "envelope")
    }
}
```

Attach `.sheet(isPresented: $showingCompose)` that vends a fresh `ComposeMessageSheet` with a new `ComposeMessageViewModel` each time.

### `ComposeMessageSheet`

**File:** `CanvasApp/Views/ComposeMessageSheet.swift`

Receives: `instructorIds: [Int]`, `client: APIClient` (via `appState.makeClient()`), `isPresented: Binding<Bool>`.

Owns: `@StateObject var vm = ComposeMessageViewModel()`.

Layout (inside a `NavigationStack` for the toolbar):
- `TextField("Subject", text: $vm.subject)`
- `TextEditor(text: $vm.body)` — expands to fill available height
- If `vm.sendError != nil`: error text in `.red` below the editor
- Toolbar leading: **Cancel** button (`isPresented = false`)
- Toolbar trailing: **Send** button — disabled when `vm.body.isEmpty || vm.isSending`; shows `ProgressView` inline while `isSending`

On `vm.didSend` becoming `true` (via `.onChange`): set `isPresented = false`.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Teacher fetch fails at course load | `instructorIds` stays `[]`; mail icon hidden; grade load unaffected |
| Send fails (network / auth) | `sendError` shown inline in sheet; student can retry or cancel |
| No instructors found (empty array) | Mail icon hidden |

---

## Files Changed / Added

| File | Change |
|---|---|
| `Sources/CanvasCore/APIClient.swift` | Add `courseTeachers()` and `sendConversation()` |
| `CanvasApp/ViewModels/CourseDetailViewModel.swift` | Add `instructorIds`, parallel teacher fetch |
| `CanvasApp/ViewModels/ComposeMessageViewModel.swift` | **New** |
| `CanvasApp/Views/CourseDetailView.swift` | Add toolbar button + sheet |
| `CanvasApp/Views/ComposeMessageSheet.swift` | **New** |
