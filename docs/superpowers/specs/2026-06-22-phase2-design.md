# CanvasCLISwift — Phase 2 Design

**Date:** 2026-06-22  
**Branch:** phase-2  
**Author:** Jackson Pike

---

## Overview

Extend the Phase 1 Canvas CLI (Swift) from a simple course+grade printer into a full-featured terminal tool with argument-parser subcommands, an interactive arrow-key TUI, a rich grade dashboard with weighted category support, and a what-if grade calculator.

---

## Architecture

### Command Structure (`swift-argument-parser`)

```
canvas                          → interactive TUI (default, no args)
canvas courses                  → print active courses + current grade
canvas grades <course-id>       → full grade breakdown for one course
canvas calc <course-id>         → what-if grade calculator (interactive)
```

The root `Canvas` command with no subcommand launches the interactive TUI. Subcommands are fast, non-interactive alternatives useful for scripting or a quick terminal check.

### File Structure

```
MyTool/
  main.swift              ← ArgumentParser root command, subcommand registration
  APIClient.swift         ← all URLSession calls (courses, enrollments, assignments, groups, submissions)
  Models.swift            ← all Codable structs
  GradeCalculator.swift   ← pure grade math (no UI, no API)
  TUI.swift               ← raw terminal mode, ANSI rendering, key input loop
  Display.swift           ← shared formatting (ANSI colors, grade letter, banner)
```

---

## Data & API

### New Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /courses/:id/assignment_groups` | Fetch groups with weights |
| `GET /courses/:id/assignments` | Fetch all assignments (points, due date, group) |
| `GET /courses/:id/submissions?student_ids[]=self` | Fetch student submissions (score, state) |

The `assignment_groups` call can include `?include[]=assignments` to co-fetch assignments in one request, reducing API round-trips.

### Models

```swift
struct Course: Codable {
    let id: Int
    let name: String
    let courseCode: String
    let applyAssignmentGroupWeights: Bool
}

struct Enrollment: Codable {
    let grades: Grades
}

struct Grades: Codable {
    let currentScore: Double?
    let currentGrade: String?
}

struct AssignmentGroup: Codable {
    let id: Int
    let name: String
    let groupWeight: Double      // 0–100; ignored when weights not applied
    let assignments: [Assignment]
}

struct Assignment: Codable {
    let id: Int
    let name: String
    let pointsPossible: Double
    let dueAt: String?
    let assignmentGroupId: Int
}

struct Submission: Codable {
    let assignmentId: Int
    let score: Double?
    let workflowState: String   // "graded" | "submitted" | "unsubmitted"
}
```

### GradedItem (internal join)

`GradeCalculator` joins Assignment + Submission into a flat `GradedItem`:

```swift
struct GradedItem {
    let assignmentId: Int
    let name: String
    let groupId: Int
    let pointsPossible: Double
    var earnedPoints: Double?       // nil = ungraded/unsubmitted
    var whatIfPoints: Double?       // set by user in calculator
}
```

---

## Grade Calculator

### Grade Math

**Unweighted** (`applyAssignmentGroupWeights == false`):
```
grade = sum(earned) / sum(possible for graded items)
```

**Weighted** (`applyAssignmentGroupWeights == true`):
```
for each group:
    group_pct = sum(earned in group) / sum(possible in group)
grade = sum(group_pct * group_weight) / sum(active group weights)
```
"Active" groups = groups that have at least one graded item.

### Calculator Modes

1. **What-if (selected assignments):** User selects one or more assignments, enters a hypothetical score (0–100%). The calculator replaces `earnedPoints` with `whatIfPoints` for selected items and recalculates. Non-selected items use their real earned score.

2. **Blanket score:** User enters a single percentage applied to ALL currently ungraded items. Recalculates as if every outstanding assignment received that score.

3. **Perfect remaining:** Sets all ungraded items to 100% and shows best-possible final grade.

All three modes can be composed: e.g., apply blanket 80% to remaining work, then override one specific exam with a what-if score.

---

## Interactive TUI

### Screens

1. **Course List** (main) — arrow keys up/down to highlight a course, Enter to open, `q` to quit
2. **Course Detail** — shows grade dashboard (score, letter, group breakdown), assignment list; `c` to open calculator, `Esc`/`b` to go back
3. **Grade Calculator** — assignment list with checkboxes, enter what-if scores per item; `b` for blanket mode, `p` for perfect remaining, `Esc` to exit

### Terminal Handling

- Use Darwin's `tcsetattr` to enter raw mode (no echo, character-at-a-time input)
- Arrow keys arrive as 3-byte escape sequences: `ESC [ A/B/C/D`
- Restore terminal state on exit (including signal handlers for SIGINT)
- Render with ANSI: clear screen (`ESC[2J`), cursor home (`ESC[H`), color codes

### Grade Dashboard Display (Course Detail)

```
CS 246 — Data Structures                    88.4%  B+
─────────────────────────────────────────────────────
 Homework        (40%)   92.1%  ████████████░░  A-
 Quizzes         (20%)   85.0%  ██████████░░░░  B
 Midterm         (20%)   84.0%  ██████████░░░░  B
 Final Project   (20%)   —      not yet graded
```

---

## Error Handling

- Missing `CANVAS_TOKEN`: print clear error and exit 1
- API 401: "Invalid token — check your CANVAS_TOKEN environment variable"
- API errors / network failure: surface message, exit gracefully (don't crash)
- Course with no assignments: show "No assignments found" in calculator screen
- Unweighted course treated differently from weighted — detected per-course, not global

---

## Out of Scope (Phase 2)

- Announcements
- To-do list / upcoming assignments view
- Submitting or modifying assignments
- Persistent config file (token stays env-var only)
