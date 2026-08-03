# Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox

## Overview
Design for the two unbuilt surfaces of the **Canvas Grades** macOS desktop window
(`CanvasApp/Views/Window/MainWindowView.swift`): the **Dashboard** detail pane (currently
`ComingSoonView(title: "Dashboard", phase: "Phase 1")`) and a promoted **What-If Sandbox**
that replaces the hidden `.inspector` in `CourseWorkspaceView.swift`.

Two things drive the design:

1. **"Points still in play."** Every course is one bar of *earned / lost / still-unawarded*,
   with a reachable **ceiling** and **floor** grade. This answers the actual end-of-semester
   question — *does this still matter?* — which a bare percentage does not.
2. **The What-If calculator is the product.** It moves out of a toggled inspector and becomes
   a persistent rail whose scope follows the selection: on the Dashboard it solves for **term
   GPA**, inside a course it solves for **that course**. Same `CalculatorViewModel`, one extra
   scope parameter.

The app also drops BYU–Hawaii red/gold for its own identity: warm neutral ink, one indigo
accent reserved exclusively for *hypothetical* values, and one burnt-orange reserved for
*lost/missing* points. `Color.letterGradeColor` (green/blue/yellow/red) is kept where a
letter grade is shown, because it carries meaning.

## About the Design Files
`Canvas Desktop.dc.html` is a **design reference created in HTML** — a prototype showing
intended look, layout and behavior. It is **not production code to copy**. The task is to
**recreate these designs in SwiftUI** inside the existing `CanvasCLISwift` app, using its
established patterns (`NavigationSplitView`, `CoursesViewModel`, `CourseDetailViewModel`,
`GradeCalculator`, the `CanvasUI` value-driven component style). Nothing in the HTML should
be ported literally.

Open the file in a browser. It is a design canvas: each `<section class="dv-turn">` is one
round of exploration, **newest at the top**, and each option has a visible id badge.

## Fidelity
**High-fidelity.** Colors, type sizes, spacing and copy are final-intent. Recreate pixel-
faithfully with SwiftUI primitives. Every number shown in the mocks is computed from
`Sources/CanvasCore/MockData.swift`, so you can verify your implementation against them
in demo mode.

## Which options are approved
| id | What it is | Status |
|----|-----------|--------|
| `3a` | Dashboard — ledger layout, **dark** | ✅ **Build this** |
| `3b` | Dashboard — identical, **light** | ✅ Build as the light theme |
| `1d` | Course workspace + Sandbox rail (dark) | ✅ Direction approved; palette matches 3a |
| `2a`/`2b` | Cards vs Ledger toggle exploration | Idea retained (see *Customization*), visuals superseded by 3a/3b |
| `1a` | Recreation of today's shipping shell | Reference only — this is the before |
| `1b`, `1c` | Earlier dashboard directions | Superseded by 3a |

---

## Screens / Views

### 1. Dashboard (`SidebarItem.dashboard` detail pane) — options `3a` / `3b`

**Purpose.** Answer, in one glance without logging in: where do I stand, what can still
change, what's rotting, and what did an instructor just say to me.

**Window.** 1040 × 730 in the mock. Real minimum stays `minWidth: 900, minHeight: 600`
(spec §5.1). Sidebar 214pt fixed; detail pane fills.

**Vertical stack of the detail pane, top to bottom:**

| Region | Height | Padding |
|---|---|---|
| Header (GPA + sentence + CTA) | intrinsic | `24 30 12` |
| Semester timeline strip | 32 + 6 label | `0 30 4` |
| Ledger table (header row + 4 course rows) | intrinsic | `14 30 0` |
| Bottom panels (2-column grid) | fills remaining | `18 30 24`, gap 26 |

#### 1.1 Header
- Left block: label `TERM GPA` — 10.5pt, weight 700, letter-spacing .12em, tertiary color.
  Below it the GPA — **58pt / line-height 0.9 / weight 700 / letter-spacing −.03em**, primary color, 8pt top margin.
- Middle: one sentence, 14.5pt, line-height 1.45, max-width 420, `text-wrap: pretty`:
  “**2,140 points** are still unawarded. Enough to reach **3.70** — or fall to **2.60**.”
  “2,140 points” is bold primary; “3.70” is bold **accent** (it's a hypothetical); “2.60” bold primary.
- Right: primary button **“Play it out →”** — 12.5pt/600, radius 7, padding 9×15, `white-space: nowrap`. Opens the Sandbox rail.
- Row is `align-items: flex-end`, gap 24.

#### 1.2 Semester timeline strip
A single horizontal rule pair (1px top and bottom border) 32pt tall, `position: relative`:
- Elapsed portion: absolute, left 0, width **61%** (fraction of term elapsed), fill `rgba(255,255,255,.035)` dark / `rgba(0,0,0,.035)` light.
- **Today** marker: 2pt vertical bar at 61%, extending 6pt above and below the rule, primary color.
- Assignment ticks, absolutely positioned circles, vertically centered:
  - past/graded — 7pt, muted (`#4A4757` dark / `#C7C2B8` light)
  - overdue/missing — 9pt, **lost** color
  - upcoming — 9pt, primary
  - final exam — 12pt, primary
- Under the strip, a 10.5pt tertiary row: `Week 1` · `today` · `Finals · Aug 16` (space-between).

Data: tick x-position = `(dueAt − termStart) / (termEnd − termStart)`.

#### 1.3 Ledger table
Column header row — 10.5pt/700, letter-spacing .09em, tertiary:
`COURSE` (184 wide) · `EARNED / LOST / IN PLAY` (flex) · `CEILING` (86, right) · `FLOOR` (70, right).

Each course row: `padding: 11 0`, 1px top divider; last row also has a bottom divider.
- **Course cell (184pt):** code at 14pt/600 primary; subtitle at 10.5pt tertiary 2pt below —
  normally the course name, but **if the course has missing work the subtitle becomes
  `1 missing quiz` in the lost color, and the whole row gets a `rgba(lost, .09)` background
  plus 8pt horizontal padding** (course cell narrows to 176 to compensate).
- **Bar cell (flex, 20pt right padding):** a 15pt-tall, 3pt-radius bar, three segments, no gaps:
  1. **earned** — width = `earnedPoints / totalTermPoints`, solid primary ink
  2. **lost** — width = `(gradedPossible − earned) / totalTermPoints`, solid lost color
  3. **in play** — remainder, 135° repeating stripe, 5pt on / 5pt off
  Under it, 10pt monospace secondary: `now 89.4% · 240 pts in play`.
- **Ceiling (86pt, right):** 16pt/700 monospace primary, with the letter beneath at 9.5pt tertiary.
- **Floor (70pt, right):** same, in the **lost** color.

Real values from `MockData` (verify against these):

| Course | now | earned/lost/in-play | pts in play | ceiling | floor |
|---|---|---|---|---|---|
| CS 101 | 89.4% | 38 / 4 / 58 | 240 | 96.2 (A) | 54.2 (F) |
| MATH 112 ⚠ | 71.1% | 24 / 11 / 65 | 120 | 85.5 (B) | 35.5 (F) |
| HIST 201 | 95.3% | 41 / 2 / 57 | 150 | 98.1 (A) | 55.3 (F) |
| REL 225 | 96.9% | 62 / 2 / 36 | 40 | 98.2 (A) | 62.9 (D-) |

#### 1.4 Bottom panels — 2-column grid, `1fr 1.15fr`, gap 26

**Left — `AWAITING GRADE` + count.** Section label 10.5pt/700/.09em tertiary, count in
monospace. Each row (`padding: 8 0`, 1px top divider, last row bottom divider too):
- 7pt course-color dot (`flex: none`)
- title 12.5pt primary, single line, ellipsis on overflow; below it 10.5pt tertiary
  `submitted Feb 24 · 25 pts`
- right: age capsule, 10.5pt monospace, padding 5×8, radius 99 — **neutral fill under 5 days,
  lost-tinted fill (`rgba(lost,.14)` dark / `.10` light) at 5+ days**. This aging rule is the
  point of the panel: it's how you notice a professor sitting on a grade.
- Footnote, 10.5pt tertiary: `Held back by the instructor: CS 101 Final Exam — graded but not
  released.` (drives off a submission with `workflowState == "graded"` and `score == nil`.)

**Right — `RECENT FEEDBACK`.** Each row: 11pt gap, `padding: 9 0`, 1px top divider.
- 26pt circle with the author's initials, 10.5pt/700, tinted with the course color at 16–20% alpha
- line 1, 12px: **author name** bold, then tertiary ` · Paper 1 — Ancient Empires · 48/50`
- line 2, 12px secondary, line-height 1.45, `text-wrap: pretty`, the comment in quotes

Content (from `MockData` submission comments): Dr. Alaimalo / Paper 1 / 48/50; Dr. Kekoa /
Problem Set 2 / 21/30; Prof. Demo / Week 1 Reflection / 18/20.

#### 1.5 Sidebar (both themes)
214pt. Traffic-light row is a 52pt spacer in the mock (real app gets it free from the window).
Nav items 13pt, `padding: 8 11`, radius 6; the selected item is 700 weight on a
`rgba(fg,.07)` fill. Inbox carries an unread pill (11pt/700, accent fill, radius 99).
Section caption `COURSES` — 10.5pt/700/.1em tertiary, `padding: 18 23 6`.
Course rows: 7pt color dot · code 13pt · **current percentage right-aligned in 12pt monospace**
(the ledger shows numbers, so the sidebar does too — this replaces today's `LetterBadge`,
though `LetterBadge` stays in use on the course workspace). A course below its target shows
its number in the lost color. Footer, 10.5pt tertiary: `Winter 2026 · 12 credits` / `Synced 2 min ago`.

---

### 2. Course workspace + Sandbox — option `1d`

**Purpose.** The grades tab of one course with the What-If calculator always visible.
Replaces `GradesTabView`'s `.inspector(isPresented:)` with a permanently docked rail.

**Toolbar row (52pt):** course code 15pt/600, then a segmented control
(`Grades | Assignments | Modules | Syllabus`) — 12pt, selected pill is a light fill with
dark text, radius 5 inside a radius-7 track with 2pt padding. Right: `Synced 2 min ago`, 11.5pt tertiary.

**Main column (flex, padding 20×22, gap 16):**
1. **Actual → Projected headline.** `ACTUAL` label + `89.4` at 40pt/700 monospace; a 22pt
   `→` in a muted color; `PROJECTED` label in accent + `92.6` at 40pt/700 monospace **in accent**;
   then the projected `LetterBadge` (`A-`, white on green, radius 99, padding 5×11). Far right,
   11.5pt: `2 hypotheticals active` / `Reset sandbox` (accent, tappable).
2. **`GROUPS`.** One row per assignment group — name (92pt) · weight (34pt, monospace tertiary)
   · 8pt-tall progress track, radius 99 · value (52pt, right, monospace). The track shows the
   **real** percentage in `letterGradeColor`, and any what-if lift as an **accent segment
   appended to the right of it**; when a group is lifted, its value text turns accent.
   (Source: `GradeCalculator.groupBreakdown()` vs `liveCalculator.groupBreakdown()`.)
3. **`ASSIGNMENTS`.** 8×10 rows, radius 8. Graded rows: `rgba(fg,.03)` fill, score in monospace
   secondary. **Hypothetical rows: accent-tinted fill + 1pt accent border, and the score is
   replaced by an accent capsule reading `what-if 91/100`.**

**Sandbox rail — 330pt (296pt for the term-scope version on the Dashboard), 1pt left border,
panel background:**
- **Header:** `Sandbox` 13pt/700, plus a scope chip (`TERM` on the dashboard, none in a course).
  Subtitle 11.5pt tertiary: *"Drag any ungraded item. Nothing here is sent to Canvas."*
  That reassurance is required — it's the top objection to a what-if tool.
- **Target block** (`I WANT TO FINISH WITH`): 4 chips — `A- | A | B+ | 90%` (letters and a
  custom percent, matching `CalculatorViewModel.TargetMode`). Selected chip is filled.
  Below, **the answer as one sentence at 14pt**:
  “Score **84%** or better on the **Final Exam** and you land an **A-**.” (84% in accent.)
  Then 11.5pt tertiary support: `= 84 / 100 pts · you're averaging 88% on exams`.
  Map `SolveResult`: `.needed(percent)` → the sentence; `.alreadyAchieved` → “You've already
  locked this in.”; `.impossible(max)` → “Out of reach — the best you can finish is 85.5%.”
- **`HYPOTHETICALS`:** one slider per active what-if. Label 12.5pt + value in accent monospace.
  Track 4pt radius-99, filled in accent; knob 16pt light circle with a shadow. On the slider
  that satisfies the target, draw a **2pt green vertical marker at the required percentage**
  with a 10.5pt green caption: *green line = the 84% you need*. This is the whole feature in
  one gesture — drag until you pass the line.
- **`SCENARIOS`:** preset chips that batch-fill the what-ifs —
  `Everything 100% → 96.2 A` · `Keep my average → 91.8 A-` · `Bomb the final → 66.6 D`.
- **Footer buttons:** `Save scenario` (accent fill) · `Pin to menu bar` (outline). "Pin" surfaces
  that scenario's projected grade in the `MenuBarExtra` popover.

**Dashboard-scope variant** (see `2a`'s rail for the layout): target chips become GPA values
(`3.5 | 3.7 | 4.0`), the sentence names a course (“Pull **MATH 112** to a **B-** and hold
everything else. That's **78%** on the final.”), sliders are per-course “remaining work”
sliders labeled `71.1 → 79.4 · C- → B-`, and a summary card shows `Projected GPA 3.50 · from
3.25 · +0.25`. Unreachable targets are stated plainly: *“4.0 is out of reach — MATH caps at 85.5%.”*

---

## Interactions & Behavior
- **Sidebar selection** — unchanged (`Router.sidebar`, persisted to `UserDefaults`).
- **Ledger row click** → `router.reveal(.course(id:tab:.grades))`.
- **Awaiting-grade / feedback row click** → `router.reveal(.assignment(courseId:assignmentId:))`.
- **“Play it out →”** and the toolbar `Sandbox` button toggle the rail. Persist the open state
  per scope; opening should be a 200ms width/opacity transition, not a pop.
- **Sliders** recompute on drag with no debounce — `GradeCalculator` is cheap and the live
  number is the whole appeal. Every dependent number (headline, group bars, ledger, GPA card)
  animates to its new value over ~180ms ease-out; **nothing re-lays-out while dragging.**
- **`Reset sandbox`** clears `whatIfEntries` and returns all accent values to primary.
- **Hover:** ledger rows and list rows get a `rgba(fg,.04)` fill; buttons/chips lighten 6%.
- **Loading:** keep the existing `SkeletonList` treatment for a cold load — skeleton the ledger
  rows and both bottom panels; show the header with a dashed GPA placeholder rather than 0.00.
- **Error:** reuse `ContentUnavailableView` exactly as `CourseListView` does today, including the
  `Update Token…` action when the message contains `Invalid token`.
- **Empty:** no courses → existing “No Active Courses”. No feedback / nothing awaiting → hide
  that panel and let the other span both columns; do not render an empty box.
- **Staleness:** the existing `StalenessLabel` moves into the sidebar footer on the Dashboard.

## State Management
Existing: `AppSession`, `CoursesViewModel` (`courses`, `letter(for:)`, `currentScore(for:)`,
`unseenChanges`, `lastSyncedAt`), `CourseDetailViewModel`, `Router`, `CalculatorViewModel`.

New:
- `DashboardViewModel` — aggregates across courses: `termGPA`, `pointsInPlay`,
  `reachableCeilingGPA`, `reachableFloorGPA`, `perCourseLedger: [CourseLedgerRow]`
  (`earnedPts`, `lostPts`, `inPlayPts`, `ceilingPercent`, `floorPercent`), `awaitingGrade: [StreamItem]`,
  `recentFeedback: [StreamItem]`, `termStart`/`termEnd` for the timeline.
- `CalculatorViewModel.scope: .course(Int) | .term` — term scope solves per-course to hit a GPA.
- `Router.dashboardDensity: .cards | .ledger` and `Router.sandboxOpen: Bool`, both persisted
  like `sidebar` is today.

**Ceiling / floor math.** `ceiling = (earned + allRemainingPossible) / totalPossible`,
`floor = earned / totalPossible` — i.e. every ungraded item at 100% vs at 0%, run through the
existing weighted-group path so `applyAssignmentGroupWeights` is respected. Add these as two
methods on `GradeCalculator` next to `currentGrade()`; they're the only new math in the design.

## Data / API gaps (blue-sky items that need work)
1. **Per-group point totals for every assignment** (graded *and* ungraded) — needed for the bar
   and for ceiling/floor. `/courses/:id/assignment_groups?include[]=assignments` already returns it;
   it just isn't retained today.
2. **Term boundaries** for the timeline — `/courses/:id?include[]=term` (`start_at`/`end_at`),
   or fall back to min/max assignment due dates.
3. **Credit hours per course** for a real GPA — `/courses/:id` does not reliably return them;
   likely a user-entered value in Settings (also the honest fix, since GPA scales vary).
4. **Per-course colors** — `/users/self/colors` (spec already has this queued for Phase 1);
   until then keep the `accentColor(for:)` hash in `MainWindowView`.
5. **Saved scenarios** — local only (`UserDefaults` or a small JSON file next to the cache).

## Customization (the "not customizable" complaint)
Two switches, both persisted in `Router`, both surfaced in the toolbar rather than buried in
Settings: **Cards / Ledger** density (see `2a` / `2b`) and **Sandbox open/closed**. Add to
`SettingsView`: default dashboard view, light/dark/system theme, per-course target grade
(feeds the "below target" coloring), and hidden-course management (already in `CoursesViewModel.hide`).

## Design Tokens

**Dark (primary theme, option `3a` / `1d`)**
| Token | Value |
|---|---|
| bg | `#17161A` |
| panel / sidebar | `#131217` |
| hairline | `rgba(255,255,255,.07)`; stronger `rgba(255,255,255,.09)`; rule `rgba(255,255,255,.12)` |
| text primary | `#EDEBF2` (pure `#FFFFFF` for course codes / GPA) |
| text secondary | `#C6C2D2` |
| text tertiary | `#9C98A8` |
| text quaternary / labels | `#6B6878` |
| accent (hypothetical) | `#7A6EFF` — text on accent is `#0F0E12` |
| lost / missing | `#E2703A` |
| in-play hatch | `repeating-linear-gradient(135deg, rgba(255,255,255,.14) 0 5px, rgba(255,255,255,.04) 5px 10px)` |
| earned bar | `#EDEBF2` |
| row highlight (missing work) | `rgba(226,112,58,.09)` |

**Light (option `3b`)**
| Token | Value |
|---|---|
| bg | `#FBFAF8` |
| panel / sidebar | `#F1EFEB` |
| hairline | `rgba(0,0,0,.07)` / `.09` / rule `.13` |
| text primary | `#17161A` |
| text secondary | `#57545E` |
| text tertiary | `#8B8894` |
| accent | `#5A4FCF` — text on accent is `#FFFFFF` |
| lost / missing | `#C2410C` |
| in-play hatch | `repeating-linear-gradient(135deg, #D9D5CC 0 5px, #F3F1EC 5px 10px)` |
| earned bar | `#2B2833` |
| bar track | `#ECE9E3` |
| row highlight | `rgba(194,65,12,.06)` |

**Letter-grade colors — unchanged, keep `BrandColors.letterGradeColor`**
`A #34A853` · `B #4285F4` · `C #FBBC04` · else `#BA0C2F`.
Note: `#FBBC04` fails contrast as text on light backgrounds — the mocks use `#C58A00` for
C-grade *text* and keep `#FBBC04` only for fills. BYUH red/gold are otherwise retired.

**Course dot colors used in the mocks** (until `/users/self/colors` lands)
CS `#14B8A6` · MATH `#3B82F6` · HIST `#8B5CF6` · REL `#EF4444`.

**Typography**
| Role | Face | Size / weight |
|---|---|---|
| UI / chrome | SF Pro (system) | 11–15pt |
| Display (GPA, editorial headers) | **Instrument Sans** 700, letter-spacing −.03em | 48–58pt |
| Numerals, all tabular data | **JetBrains Mono** 500/700 | 9.5–17pt |
| Section labels | system 700, letter-spacing .09–.12em, uppercase | 10.5pt |
In SwiftUI, `.monospacedDigit()` on the system font is an acceptable substitute for
JetBrains Mono if you'd rather not bundle a face; the display face matters more than the mono.

**Spacing** 2 · 4 · 6 · 8 · 11 · 14 · 18 · 22 · 26 · 30
**Radius** 3 (bars) · 6–7 (chips, buttons) · 10–14 (cards) · 99 (capsules)
**Shadow** cards `0 1px 4px rgba(0,0,0,.08)`; slider knob `0 1px 4px rgba(0,0,0,.5)` dark / `0 1px 3px rgba(0,0,0,.22)` light

## Assets
None. Every icon in the mock is a hand-rolled SVG **placeholder for an SF Symbol** — use the
real symbols: `square.grid.2x2`, `tray`, `calendar`, `checklist`, `arrow.clockwise`,
`gearshape`, `function`, `clock`, `checkmark.circle`, `bubble.left`. No images, no fonts to
ship except optional Instrument Sans / JetBrains Mono from Google Fonts.

## Files
- `Canvas Desktop.dc.html` — the full design canvas (all options, newest turn first). Open in a browser.
  - `#3a` dark dashboard · `#3b` light dashboard · `#1d` course workspace + Sandbox
  - `#2a`/`#2b` Cards vs Ledger toggle · `#1a` recreation of today's shell · `#1b`/`#1c` earlier directions

Source files the design was derived from (read these before implementing):
`CanvasApp/Views/Window/MainWindowView.swift`, `CanvasApp/Views/Window/CourseWorkspaceView.swift`,
`CanvasApp/App/Router.swift`, `Sources/CanvasUI/{GradeDashboard,CourseCard,StreamSection,LetterBadge,CalculatorView,CalculatorViewModel,BrandColors}.swift`,
`Sources/CanvasCore/{GradeCalculator,MockData}.swift`.
