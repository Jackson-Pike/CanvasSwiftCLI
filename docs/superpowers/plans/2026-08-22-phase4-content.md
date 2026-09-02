# Phase 4 — Content (Modules, Files, Quick Look, ⌘K Quick-Open) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

The master design spec ([`2026-08-01-desktop-app-design.md`](file:///Users/kahuku-air/Developer/CanvasCLISwift/docs/superpowers/specs/2026-08-01-desktop-app-design.md), §5.3, §5.7, §9) defines **Phase 4 — Content** as:
1. **Modules (`CourseWorkspaceView` tab `.modules`)**:
   - Codable models (`Module`, `ModuleItem`) and SwiftData `@Model CachedModule` / `CachedModuleItem`.
   - APIClient `/api/v1/courses/:id/modules?include[]=items` (with `DEMO` mock data).
   - SyncEngine sync scopes & repository queries for modules and items.
   - SwiftUI components: collapsible module sections, module item rows (pages, links, quizzes, files, assignments) with completion status icons.
2. **Files & Quick Look (`CourseWorkspaceView` tab `.files`)**:
   - Codable models (`CanvasFile`, `CanvasFolder`) and SwiftData `@Model CachedFile` / `CachedFolder`.
   - APIClient `/api/v1/courses/:id/files` and `/folders`.
   - File download manager / local caching in App Sandbox.
   - macOS Quick Look preview integration (`quickLookPreview` or `QLPreviewController` wrapper) triggered by spacebar or click.
3. **Quick-Open & Search (`⌘K`)**:
   - Global modal search overlay triggered by `⌘K` or search button in toolbar.
   - Full-text search queries across courses, assignments, announcements, discussions, and files.
   - Instant navigation to selected search result via `router.reveal(...)`.

Phase 0 (Foundation), Phase 1a/1b (Dashboard & Course Workspace), and Phase 2 (Communication) are completed and merged with passing tests.

> **Correction (2026-09-01):** an audit found that despite the checkboxes below being marked complete,
> neither Phase 3 (Time) nor Phase 4 (Content) had ever been committed — both sat uncommitted in the
> working tree, and the "Phase 3 ... completed and merged" claim above was not yet true. Phases 3 and 4
> were verified (build green; Core + delta data suites passing) and **landed together** on 2026-09-01 in
> two commits (`feat(data): Phase 3+4 core+data …`, `feat(app): Phase 3+4 UI …`), not sequentially. See
> `docs/superpowers/PROJECT-STATUS.md` for current state.

**Current stubs this plan fills:**
- [`CourseWorkspaceView.swift:46`](file:///Users/kahuku-air/Developer/CanvasCLISwift/CanvasApp/Views/Window/CourseWorkspaceView.swift#L46) renders `ComingSoonView` for `.modules` and `.files` — replaced by `ModulesTabView` and `FilesTabView`.
- Quick-open search overlay (`⌘K`) added to `MainWindowView`.

Goal after this plan: `ModulesTabView` renders interactive module trees with completion state; `FilesTabView` provides folder navigation, file downloads, and Quick Look previews; `⌘K` overlay provides instant cross-entity search; all supported with unit tests and walkable in `DEMO` mode.

## Architecture

New decode/predicate logic (Module/Item decoding, File/Folder decoding, file path resolution, search indexing) lands as **pure, XCTest-covered functions** in `CanvasCore`/`CanvasData`. Sync and storage are tested in `CanvasDataTests` using an in-memory `ModelContainer` (`CanvasStore.container(inMemory: true)`) + `DEMO` `APIClient` harness. API endpoints are covered in `CanvasCoreTests`.

SwiftUI components live as value-driven views in `CanvasUI`. ViewModels in `CanvasApp` connect `AppSession`/`CanvasRepository` to the view layer.

## Global Constraints

- **Test framework:** XCTest only, `@testable import`. Every model, API endpoint, sync actor, repository query, and search algorithm has automated unit tests.
- **Demo verifiability:** walkable end-to-end with `CANVAS_TOKEN=DEMO`. `MockData` expands to return synthetic modules, module items, folder tree, and files.
- **SF Symbols:** `doc.text`, `link`, `doc.fill`, `square.and.pencil`, `questionmark.circle`, `folder`, `doc`, `magnifyingglass`, `checkmark.circle.fill`, `circle`, `lock.fill`, `arrow.down.circle`.
- **Quick Look:** Use macOS `QuickLook` framework or `quickLookPreview` modifier.

---

## File Structure

**Create:**
- `Sources/CanvasCore/ModuleModels.swift` — `Module`, `ModuleItem`, `CompletionRequirement`.
- `Sources/CanvasCore/FileModels.swift` — `CanvasFile`, `CanvasFolder`.
- `Tests/CanvasCoreTests/ModuleModelsTests.swift`, `Tests/CanvasCoreTests/FileModelsTests.swift`, `Tests/CanvasCoreTests/ModuleAPITests.swift`, `Tests/CanvasCoreTests/FileAPITests.swift`.
- `Sources/CanvasData/Models/ModuleModels.swift` — `@Model CachedModule`, `@Model CachedModuleItem`.
- `Sources/CanvasData/Models/FileModels.swift` — `@Model CachedFolder`, `@Model CachedFile`.
- `Tests/CanvasDataTests/ModuleSyncTests.swift`, `Tests/CanvasDataTests/FileSyncTests.swift`, `Tests/CanvasDataTests/SearchRepositoryTests.swift`.
- `Sources/CanvasUI/ModuleComponents.swift` — `ModuleSectionView`, `ModuleItemRow`.
- `Sources/CanvasUI/FileComponents.swift` — `FolderTreeView`, `FileRow`, `FileQuickLookView`.
- `Sources/CanvasUI/QuickOpenView.swift` — `QuickOpenOverlay`, `SearchResultRow`.
- `CanvasApp/ViewModels/ModulesViewModel.swift`, `CanvasApp/ViewModels/FilesViewModel.swift`, `CanvasApp/ViewModels/QuickOpenViewModel.swift`.
- `CanvasApp/Views/Window/ModulesTabView.swift`, `CanvasApp/Views/Window/FilesTabView.swift`.

**Modify:**
- `Sources/CanvasCore/APIClient.swift` — add `modules(courseId:)`, `folders(courseId:)`, `files(courseId:)`, `downloadFile(url:to:)`.
- `Sources/CanvasCore/MockData.swift` — synthetic modules, module items, folders, files.
- `Sources/CanvasData/CanvasStore.swift` — add `CachedModule.self`, `CachedModuleItem.self`, `CachedFolder.self`, `CachedFile.self` to `Schema`.
- `Sources/CanvasData/SyncEngine.swift` — extend `SyncScope` (`.modules`, `.files`), `EntityKind`, sync methods and upserts.
- `Sources/CanvasData/CanvasRepository.swift` — `modules(courseId:)`, `folders(courseId:)`, `files(courseId:)`, `filesInFolder(folderId:)`, `search(query:)`.
- `CanvasApp/Views/Window/CourseWorkspaceView.swift` — wire `ModulesTabView` and `FilesTabView`.
- `CanvasApp/Views/Window/MainWindowView.swift` — wire `⌘K` search overlay trigger and search button.

---

# GROUP A — CORE MODELS & API CLIENT (CanvasCore)

### Task 1: `Module` & `ModuleItem` Decode Models (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/ModuleModels.swift`
- Test: `Tests/CanvasCoreTests/ModuleModelsTests.swift`

- [x] **Step 1: Write failing tests for Module and ModuleItem decoding**
- [x] **Step 2: Implement `Module`, `ModuleItem`, `CompletionRequirement` structs in `CanvasCore`**
- [x] **Step 3: Run `swift test --filter ModuleModelsTests` and pass**

---

### Task 2: `CanvasFile` & `CanvasFolder` Decode Models (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/FileModels.swift`
- Test: `Tests/CanvasCoreTests/FileModelsTests.swift`

- [x] **Step 1: Write failing tests for CanvasFile and CanvasFolder decoding**
- [x] **Step 2: Implement `CanvasFile`, `CanvasFolder` structs in `CanvasCore`**
- [x] **Step 3: Run `swift test --filter FileModelsTests` and pass**

---

### Task 3: API Client Endpoints for Modules & Files (`CanvasCore`)

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Test: `Tests/CanvasCoreTests/ModuleAPITests.swift`
- Test: `Tests/CanvasCoreTests/FileAPITests.swift`

- [x] **Step 1: Write failing API client tests for `modules`, `folders`, `files`, `downloadFile`**
- [x] **Step 2: Add methods to `APIClient.swift` with `DEMO` mode short-circuits**
- [x] **Step 3: Run `swift test --filter ModuleAPITests` and `swift test --filter FileAPITests`**

---

### Task 4: Extended Mock Data (`CanvasCore`)

**Files:**
- Modify: `Sources/CanvasCore/MockData.swift`

- [x] **Step 1: Add synthetic `modules`, `moduleItems`, `folders`, and `files` to `MockData.swift`**

---

# GROUP B — DATA PERSISTENCE & SYNC (CanvasData)

### Task 5: SwiftData Models for Modules & Files (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/Models/ModuleModels.swift`
- Create: `Sources/CanvasData/Models/FileModels.swift`
- Modify: `Sources/CanvasData/CanvasStore.swift`
- Test: `Tests/CanvasDataTests/ModuleModelsTests.swift`

- [x] **Step 1: Create `@Model CachedModule`, `@Model CachedModuleItem`, `@Model CachedFolder`, `@Model CachedFile`**
- [x] **Step 2: Add models to `CanvasStore.schema`**
- [x] **Step 3: Run `swift test --filter CanvasStoreTests`**

---

### Task 6: `SyncEngine` Sync Scopes for Modules & Files (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Test: `Tests/CanvasDataTests/ModuleSyncTests.swift`
- Test: `Tests/CanvasDataTests/FileSyncTests.swift`

- [x] **Step 1: Add `.modules(courseId)` and `.files(courseId)` to `SyncScope` (6h TTL)**
- [x] **Step 2: Implement `syncModules` and `syncFiles` in `SyncEngine`**
- [x] **Step 3: Run `swift test --filter ModuleSyncTests` and `swift test --filter FileSyncTests`**

---

### Task 7: `CanvasRepository` Queries & Full-Text Search (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/CanvasRepository.swift`
- Test: `Tests/CanvasDataTests/SearchRepositoryTests.swift`

- [x] **Step 1: Write repository search tests**
- [x] **Step 2: Add `modules(courseId:)`, `folders(courseId:)`, `files(courseId:)`, `filesInFolder(folderId:)`, `updateLocalPath(fileId:path:)` to `CanvasRepository`**
- [x] **Step 3: Implement `search(query:)` across courses, assignments, announcements, discussions, files, and module items**
- [x] **Step 4: Run `swift test --filter SearchRepositoryTests`**

---

# GROUP C — MODULES UI (CanvasUI & CanvasApp)

### Task 8: `CanvasUI` Module Components (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/ModuleComponents.swift`

- [x] **Step 1: Implement `ModuleSectionView` and `ModuleItemRow`**
  - Section header with collapse toggle and progress indicator
  - Indented item rows with completion state icons and item type badges
  - Click action passing `RevealTarget` or external URL

---

### Task 9: `ModulesViewModel` & `ModulesTabView` (`CanvasApp`)

**Files:**
- Create: `CanvasApp/ViewModels/ModulesViewModel.swift`
- Create: `CanvasApp/Views/Window/ModulesTabView.swift`

- [x] **Step 1: Implement `ModulesViewModel` observing repository module updates**
- [x] **Step 2: Implement `ModulesTabView` with search/filter, skeleton loading, and empty state**

---

# GROUP D — FILES & QUICK LOOK UI (CanvasUI & CanvasApp)

### Task 10: `CanvasUI` File Components & Quick Look (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/FileComponents.swift`

- [x] **Step 1: Implement `FolderTreeView`, `FileRow`, and `FileQuickLookView` wrapper**
  - Folder navigation & breadcrumb trail
  - File size formatting & last modified dates
  - Download action button with progress indicator
  - Quick Look preview integration (`.quickLookPreview` or `QLPreviewController` wrapper)

---

### Task 11: `FilesViewModel` & `FilesTabView` (`CanvasApp`)

**Files:**
- Create: `CanvasApp/ViewModels/FilesViewModel.swift`
- Create: `CanvasApp/Views/Window/FilesTabView.swift`

- [x] **Step 1: Implement `FilesViewModel` managing download tasks and active Quick Look URL**
- [x] **Step 2: Implement `FilesTabView` with folder navigation, file download, and Quick Look spacebar shortcut**

---

# GROUP E — QUICK-OPEN & SEARCH (`⌘K`) (CanvasUI & CanvasApp)

### Task 12: `QuickOpenView` & `QuickOpenViewModel` (`CanvasUI` / `CanvasApp`)

**Files:**
- Create: `Sources/CanvasUI/QuickOpenView.swift`
- Create: `CanvasApp/ViewModels/QuickOpenViewModel.swift`

- [x] **Step 1: Implement `QuickOpenViewModel` executing live repository search**
- [x] **Step 2: Implement `QuickOpenOverlay` modal view**
  - Keyboard navigation (Up/Down arrows, Return to select, Escape to close)
  - Grouped search results (Courses, Assignments, Announcements, Discussions, Files)
  - Instant navigation via `router.reveal(target)`

---

# GROUP F — INTEGRATION & VERIFICATION

### Task 13: Wire Navigation & Scenes (`CanvasApp`)

**Files:**
- Modify: `CanvasApp/Views/Window/CourseWorkspaceView.swift`
- Modify: `CanvasApp/Views/Window/MainWindowView.swift`

- [x] **Step 1: Replace `.modules` and `.files` stubs in `CourseWorkspaceView` with `ModulesTabView` and `FilesTabView`**
- [x] **Step 2: Add `⌘K` keyboard shortcut and toolbar search button in `MainWindowView` to open `QuickOpenOverlay`**

---

### Task 14: Comprehensive Verification

- [x] **Step 1: Run full test suite: `swift test`**
- [x] **Step 2: Walk `DEMO` mode end-to-end**
  - Launch app with `CANVAS_TOKEN=DEMO`.
  - Open Course Workspace -> **Modules**: verify collapsible sections, completion icons, item clicking.
  - Open Course Workspace -> **Files**: verify folder tree, download action, Quick Look preview.
  - Press `⌘K`: verify search modal appears, query searching works, arrow key selection navigates smoothly.

---

## Summary of Deliverables

| Component | Location | Description |
|---|---|---|
| Module & File Models | `CanvasCore` | `Module`, `ModuleItem`, `CanvasFile`, `CanvasFolder` |
| API Client Calls | `CanvasCore` | `modules`, `folders`, `files`, `downloadFile` |
| SwiftData Storage Models | `CanvasData` | `@Model CachedModule`, `CachedModuleItem`, `CachedFolder`, `CachedFile` |
| Sync & Search Repository | `CanvasData` | Sync engine `.modules` / `.files`, search query |
| Module & File UI Components | `CanvasUI` | Collapsible module sections, file tree, Quick Look wrapper |
| Quick-Open Modal | `CanvasUI` & `CanvasApp` | `⌘K` search overlay with keyboard navigation |
| Course Workspace Tabs | `CanvasApp` | `ModulesTabView` & `FilesTabView` |
