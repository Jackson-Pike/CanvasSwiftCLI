# Demo Mode Design

**Date:** 2026-06-27  
**Status:** Approved

## Problem

Canvas returns no active courses once the semester ends. Without real data the app's course list, grade dashboard, stream, and calculator views are untestable during semester breaks.

## Goal

Inject a complete fake course — including assignment groups, assignments, submissions, and instructor feedback — that fully exercises every currently rendered UI element. Activated by entering `DEMO` as the API token. Gated behind `#if DEBUG`; zero impact on release builds.

## Activation

The user enters `DEMO` into the token field in Settings (or Welcome) exactly as they would a real token. `AppState.saveToken("DEMO")` stores it via Keychain. `AppState.makeClient()` returns `APIClient(token: "DEMO")`.

Each public API method in `APIClient` short-circuits at the top of its body when `token == "DEMO"` under a `#if DEBUG` guard, returning mock data directly without touching the network.

## File Layout

One new file:

```
Sources/CanvasCore/MockData.swift   ← all fake data, #if DEBUG only
```

No other files in `CanvasCore` change structurally. `APIClient.swift` gains `#if DEBUG` guard blocks at the top of each of its five public methods:

- `courses()`
- `enrollments(courseId:)`
- `assignmentGroups(courseId:)`
- `submissions(courseId:)`
- `courseTeachers(courseId:)`

No ViewModel changes. No protocol extraction.

## Mock Data

### Course

| Field | Value |
|---|---|
| `id` | `99999` |
| `name` | `"Intro to Software Engineering"` |
| `courseCode` | `"CS 101"` |
| `applyAssignmentGroupWeights` | `true` |
| `gradingScheme` | `nil` (uses BYUH default scale) |

### Enrollment

`currentScore: 87.2`, `currentGrade: "B+"` — enough to render a colored grade badge on the course card.

### Assignment Groups

Three groups; weights sum to 100.

#### Homework (weight: 30, id: 1001)

| id | name | pointsPossible | dueAt |
|---|---|---|---|
| 201 | "Week 1 Reflection" | 20 | past |
| 202 | "Week 2 Reflection" | 20 | past |
| 203 | "Week 3 Reflection" | 20 | past |
| 204 | "Week 4 Reflection" | 20 | past |

All four have graded submissions. Assignment 201's submission includes an instructor feedback comment (authorId ≠ student userId) to populate the Feedback stream section.

#### Quizzes (weight: 30, id: 1002)

| id | name | pointsPossible | dueAt |
|---|---|---|---|
| 301 | "Quiz 1 — Variables" | 25 | past |
| 302 | "Quiz 2 — Functions" | 25 | past |
| 303 | "Quiz 3 — Objects" | 25 | past |

Submissions: 301 and 302 are `graded`. 303 is `workflowState: "submitted"` with no score — populates the **Awaiting Grade** stream section.

#### Exams (weight: 40, id: 1003)

| id | name | pointsPossible | dueAt |
|---|---|---|---|
| 401 | "Midterm Exam" | 100 | past |
| 402 | "Final Exam" | 100 | future (+14 days from build time) |

Midterm has a graded submission (populates **Recently Graded**). Final has no submission and a future `dueAt` (populates **Upcoming**).

### Scores

Chosen so `GradeCalculator` produces ~87% overall:

| Assignment | Score / Possible |
|---|---|
| 201 | 18 / 20 |
| 202 | 19 / 20 |
| 203 | 17 / 20 |
| 204 | 20 / 20 |
| 301 | 22 / 25 |
| 302 | 24 / 25 |
| 401 | 85 / 100 |

### Instructor Feedback Comment (on submission for 201)

```
authorId:   88888   (a fake teacher id, ≠ student userId 77777)
authorName: "Prof. Demo"
comment:    "Great reflection — keep pushing your analysis deeper."
createdAt:  ISO8601 timestamp ~3 days ago
```

### `courseTeachers(courseId:)`

Returns `[88888]` — matches the feedback comment's `authorId`.

## Stream Coverage

| Section | Triggered by |
|---|---|
| Awaiting Grade | Quiz 3 submission (`workflowState: "submitted"`, no score) |
| Upcoming | Final Exam (future `dueAt`, no submission) |
| Recently Graded | Midterm Exam (graded, recent `gradedAt`) |
| Recent Feedback | Week 1 Reflection comment from Prof. Demo |

## Maintenance

When a new field is added to an existing model, update `MockData.swift` to populate it. When a new API endpoint is added, add a corresponding `#if DEBUG` branch to that `APIClient` method. Missing mock data surfaces as empty UI — it does not crash or silently lie.

## Non-Goals

- No UI toggle (no Settings switch)
- No URLSession-level interception (that belongs in the test suite, not demo mode)
- No release-build impact
- No support for multiple fake courses (one is enough for dev work)
