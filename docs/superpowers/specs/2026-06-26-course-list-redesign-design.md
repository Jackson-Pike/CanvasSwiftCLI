# Course List Redesign — Billboard Grade Cards

**Date:** 2026-06-26
**Status:** Approved

---

## Goal

Replace the current compact plain-list rows with full-width "billboard" cards. Each card shows the course name large on the left and a soft-tinted grade slab on the right with a large letter grade. Everything a student needs — name, score, grade — is readable in one glance without tapping in.

---

## Visual Design

### Card anatomy

```
┌────────────────────────────────────────────┐
│                           │░░░░░░░░░░░░░░░│
│  adv web dev              │░░░░░░░░░░░░░░░│
│  2026 Spr CS 490R Sec01   │░░░░  A  ░░░░░│
│  94.2%                    │░░░░░░░░░░░░░░░│
│                           │░░░░░░░░░░░░░░░│
└────────────────────────────────────────────┘
   white card, 16pt corners        soft grade-color slab
```

### Typography

| Element | Style |
|---------|-------|
| Course nickname | `.title3.bold()`, `.primary` |
| Course code | `.caption`, `.secondary` |
| Score percentage | `.headline.monospacedDigit()`, `.secondary` |
| Letter grade | `Font.system(size: 44, weight: .bold)`, deep grade color |

### Slab

- Fixed width: 90pt
- Full card height, clipped with `16pt` corner radius on the right side only
- Background: soft tint of the letter grade color (`.opacity(0.15)`)
- Letter color: full-saturation version of the grade color (matches existing `Color.letterGradeColor`)

### Grade color mapping (existing system)

| Letter | Slab tint | Letter color |
|--------|-----------|--------------|
| A | green @ 15% opacity | `letterGradeColor("A")` (green) |
| B | blue @ 15% opacity | `letterGradeColor("B")` (blue) |
| C | yellow @ 15% opacity | `letterGradeColor("C")` (yellow) |
| D / F | red @ 15% opacity | `letterGradeColor("D")` (byuhRed) |
| No grade | `.secondary` @ 15% opacity | `.secondary` |

### No-grade state

When `score` is `nil`, the slab uses a neutral gray tint and the letter shows `—` in secondary color.

### Card chrome

- Background: `Color(.systemBackground)` (white in light mode)
- Corner radius: 16pt
- Shadow: `shadowRadius: 4, y: 2, opacity: 0.08` — subtle lift
- Outer background (behind cards): `Color(.systemGroupedBackground)` (light gray)
- Vertical gap between cards: 12pt

---

## Layout / List Structure

Keep `List` to preserve swipe-to-hide. Style it to look like cards:

- `.listStyle(.plain)`
- `.listRowBackground(Color.clear)` — removes the white List row background
- `.listRowSeparator(.hidden)` — no divider lines
- `.listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))` — gap between cards
- `List` itself backed by `Color(.systemGroupedBackground)`

`CourseRowView` is renamed `CourseCardView` and its body becomes:

```
ZStack(alignment: .trailing) {
    RoundedRectangle(16)                  // white card
        .fill(Color(.systemBackground))
        .shadow(...)
    HStack(spacing: 0) {
        VStack(alignment: .leading) {     // left: name, code, score
            Text(course.name)             // .title3.bold
            Text(course.courseCode)       // .caption .secondary
            Text(scoreString)             // .headline.monospacedDigit
        }
        .padding(16)
        Spacer()
        slabView                          // 90pt wide tinted slab
    }
    .clipShape(RoundedRectangle(16))
}
```

The slab clips cleanly to the card's right rounded corners via `clipShape` on the outer `HStack`.

---

## Files Changed

| File | Change |
|------|--------|
| `CanvasApp/Views/CourseListView.swift` | Rename `CourseRowView` → `CourseCardView`; rewrite body with card layout; update `List` modifiers |

No new files. No model or ViewModel changes required.

---

## Out of Scope

- Per-course accent color derived from Canvas API (planned in student UX brief — future)
- Grade ring / Gauge (Option A from brainstorm — not chosen)
- Animation or transition on grade number
