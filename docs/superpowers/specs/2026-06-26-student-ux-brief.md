# Student UX Brief — CanvasCLISwift

**Date:** 2026-06-26  
**Source:** Student-perspective UI audit of current codebase  
**Purpose:** Prioritized backlog of QoL improvements, visual polish, and missing functionality

---

## Context

This brief captures findings from a student-perspective review of the app on branch `worktree-phase-3-swiftui`. The app currently features: Canvas API auth (Keychain), course list with color-coded letter-grade badges, swipe-to-hide, course detail with per-group breakdown and progress bars, a What-If calculator, a Solve-For-Me grade solver, and 5-minute API caching.

One structural note: active code still targets **macOS MenuBarExtra** (`Color(nsColor:)`, `MenuBarExtra`). Phase 3 is an iOS migration — some items below are iOS-specific and require that porting work first.

---

## Quick Wins (implement first)

These are high-value, low-effort items that make an immediate difference to daily use.

| # | Feature | Notes | Effort |
|---|---------|-------|--------|
| 1 | **Upcoming assignments / due dates view** | `Assignment.dueAt` is already fetched and parsed — just not displayed. A student's #1 daily use case. | M |
| 2 | **Missing/overdue indicators** | `Submission.workflowState` is fetched but unused. Flag `unsubmitted` items prominently. | S–M |
| 3 | **Pull-to-refresh** (`.refreshable`) | Expected iOS gesture. The toolbar button is a small, easy-to-miss target. | S |
| 4 | **"Last updated" timestamp** | `lastFetchedAt` already exists on the VM. Students need to know if a grade is stale. | S |
| 5 | **Points alongside percentage** in group breakdown (e.g. "182 / 200 pts") | Students think in points remaining, not just percentages. | S |
| 6 | **Haptic feedback** on refresh, solver results, hide-course | `.success` / `.warning` notification haptics at emotionally loaded moments. | S |
| 7 | **Tap assignment in Canvas web** | Deep-link to the submission page so students can read feedback. Cheap bridge until native feedback exists. | S |
| 8 | **`.keyboardType(.decimalPad)`** on What-If score fields | Prevents letter input in numeric fields. | S |

---

## QoL Improvements

Friction-reducers for everyday use.

- **Expandable assignment list inside group breakdown** — currently the only way to see individual assignments is the calculator. "Why did my grade drop?" requires opening What-If and hunting. Tapping a group row should expand its assignments in-place. *(Effort: M)*
- **Sort / filter course list** — by grade, by name, by "needs attention." Reduces noise when enrolled in 5+ courses. *(Effort: S)*
- **Search bar** (`.searchable`) on the course list — trivial to add, high utility at scale. *(Effort: S)*
- **Persist cache across launches** — currently all caching is in-memory; cold starts always show a spinner. A plan for this already exists (`docs/superpowers/plans/2026-06-25-api-caching.md`). *(Effort: M)*
- **Cross-course GPA / average summary** — no aggregate view exists. A header or summary card with overall average is expected by students in any grades app. *(Effort: M)*
- **"What changed" / new-grade highlighting** — diff against the previous fetch and badge newly graded items. This is the primary reason students open Canvas repeatedly throughout the day. *(Effort: M)*
- **Course pinning / manual reorder** — hide exists but there's no way to pin the 1–2 courses you care about most to the top. *(Effort: M)*
- **Graceful token re-auth flow** — expired tokens currently produce a raw error string. A dedicated "Token expired — tap to re-enter" state reduces confusion. *(Effort: S)*

---

## Visual Polish

Small changes with outsized perceptual impact.

- **Grade ring / `Gauge`** for overall course percentage — replaces plain text with a scannable at-a-glance dashboard element. *(Effort: M)*
- **`.contentTransition(.numericText())`** on grade numbers — animates digit changes after a refresh, making the app feel alive. *(Effort: S)*
- **Progress-bar fill animation** on group breakdown when the detail view appears — respects Reduce Motion. *(Effort: S)*
- **Skeleton loading rows** instead of a bare centered `ProgressView("Loading…")` — feels faster even when it isn't. *(Effort: M)*
- **Per-course accent color** — Canvas assigns course colors; or derive one from the course code. A colored leading bar per row makes the list far easier to scan and feels personalized. *(Effort: M)*
- **Gradient / Liquid Glass depth on letter-grade badges** — flat fills work but a touch of depth reads as premium on iOS 26. *(Effort: S)*
- **Celebratory moment** when solver returns `.alreadyAchieved` — confetti or a sparkle. High-emotion student moment that currently shows only a green label. *(Effort: S–M)*

---

## Larger Features (future scope)

Higher effort, but high student value.

- **Local notifications** for new grades and upcoming due dates — no server required; transforms the app from manual-check to proactive companion. *(Effort: L)*
- **Grade trend / history sparkline** — requires storing grade snapshots over time; even a "↑ since yesterday" arrow is motivating. *(Effort: L)*
- **Individual assignment detail view** — score, points earned, due date, rubric. Currently invisible outside the calculator. *(Effort: M–L)*

---

## Prioritized Implementation Order

1. Pull-to-refresh + "last updated" label *(immediate polish, S)*
2. Surface `dueAt` in an Upcoming Due Dates view *(highest student value, data already available)*
3. Flag missing submissions using `workflowState` *(high anxiety-reduction value)*
4. Haptics + `.numericText()` grade transitions *(maximum polish per line of code)*
5. Expandable assignment rows in group breakdown *(answers "why did my grade change?")*
6. Points alongside percentage in breakdown
7. Tap-to-open assignment in Canvas web
8. Cross-course GPA summary card
9. Persist cache across launches (see existing caching plan)
10. "What changed" new-grade highlighting
