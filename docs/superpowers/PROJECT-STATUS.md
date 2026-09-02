# Project Status — Canvas Grades (Windowed Desktop Client)

**Last updated:** 2026-09-01

This is the single trustworthy entry point for "where is the project." It supersedes the README and
`docs/changelog.md`, which still describe the *original menu-bar grades popover* and have not been updated
for the windowed client.

## What this project actually is

A **windowed macOS Canvas student client** (macOS 14+), not just the menu-bar grades popover. One process
runs **two scenes** — the `MenuBarExtra` popover and a full `Window` (`NavigationSplitView`) — over one
shared `AppSession` + `Router`. Governed by the master design spec
[`specs/2026-08-01-desktop-app-design.md`](specs/2026-08-01-desktop-app-design.md).

**Architecture:** clean 4-layer SPM graph, no third-party dependencies:

```
CanvasCore  →  CanvasData  →  CanvasUI  →  CanvasApp
(models,       (SwiftData    (shared      (@main, two scenes,
 APIClient,     store, one    SwiftUI      AppSession, Router)
 GradeCalc,     writer =      components,
 MockData)      SyncEngine,   design
                one reader =   system)
                Repository)
```

`SyncEngine` (`@ModelActor`) is the only thing that fetches from Canvas and the only thing that writes to
the store; views read through `CanvasRepository` and never call `APIClient`. ~13,850 lines of source.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 — Foundation | Package split, SwiftData store, SyncEngine, Router, window shell | ✅ committed |
| 1 — Course workspace | Assignments, Announcements, Syllabus, expanded Grades, Dashboard | ✅ committed |
| 2 — Communication | Inbox, Discussions (read-only), Notifications, background refresh, Settings | ✅ committed |
| 3 — Time | Calendar (month/week/agenda), To-Do triage, due-soon strips | ✅ **landed 2026-09-01** |
| 4 — Content | Modules, Files + Quick Look, ⌘K Quick-Open + cross-entity search | ✅ **landed 2026-09-01** |
| 5 — Submission | Upload / text / URL entry, confirmation, verification round-trip | ❌ not started |

**Phases 3 & 4 history:** both were fully implemented but left **uncommitted** in the working tree (their
plan checkboxes were marked done prematurely). An audit on 2026-09-01 verified and landed them together in
two commits — `feat(data): Phase 3+4 core+data …` and `feat(app): Phase 3+4 UI …` — after confirming a
green `swift build`, a passing `CanvasCoreTests` suite, and passing delta data suites (PlannerSync,
ModuleSync, FileSync, SearchRepository, ToDoTriage, DueSoonChange, PlannerModelsData). Two small audit
gaps were fixed in the process: ⌘K arrow-key/ESC navigation was unwired, and the Calendar/To-Do course
palette was de-duplicated into `Color.courseAccentMap` in `BrandColors`.

## Known debt (candidates for the next planning pass)

- **Full-suite `swift test` hangs.** Running the merged bundle deadlocks at the first SwiftData suite
  (`AnnouncementSyncTests`, pre-existing Phase 1b) on the current toolchain (tools-version 5.9 compiled by
  a Swift 6.3 / Xcode 26.5 toolchain). Core tests and per-feature `--filter` runs complete fine. Worth
  root-causing — likely the SwiftData-under-concurrency risk flagged in spec §10.
- **UI/App layers untested.** CanvasUI (~4,700 lines) and CanvasApp (~4,500 lines) — ~66% of the code —
  have zero automated tests; every view and view-model is unverified.
- **`CoursesViewModel` is the last `ObservableObject` holdout** among otherwise `@Observable` view-models,
  and the one lifted into `AppSession` as a shared singleton — an unfinished migration.
- **Course accent colors are a hash/enumeration fallback;** `GET /users/self/colors` is never fetched, so
  real Canvas course colors don't appear. `DashboardViewModel.dotColor` mirrors the sidebar hash logic.
- **What-if hypotheticals aren't persisted** (`Sources/CanvasUI/SandboxRail.swift:165` — "TODO Phase 1a").
- **The DEMO seam lives inside production `APIClient`** (every method branches on `token == "DEMO"`)
  rather than being isolated behind a transport protocol.
- **README / `docs/changelog.md` are stale** (describe the popover-only grades app). A rewrite is deferred.

## Next up

The last spec'd phase is **Phase 5 — Submission** (`specs/2026-08-01-desktop-app-design.md` §7): the
assignment upload / text / URL flow with a confirmation sheet and a verification round-trip. Its plan is
not yet written. Before or alongside it, the full-suite test hang and the UI/App test gap are the highest-
value stability items.
