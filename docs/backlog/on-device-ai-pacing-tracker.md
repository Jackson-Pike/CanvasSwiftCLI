# Backlog: On-Device AI Pacing Tracker (per-course "behind risk")

**Status:** Idea / designed, not started
**Mockup:** https://claude.ai/code/artifact/4ac59a4f-ba83-4f3f-8e8a-e3798f1e80b8

## Summary

A per-course pacing section in CourseDetail that is both *reactive* ("you might be
behind if…") and *anticipatory* ("you should get started on X — it'll take a while"),
powered by Apple's on-device **Foundation Models** framework (iOS 26+ / the app's iOS 27
target). Local-only: no network, no data leaves the device.

**Core principle — math decides, AI narrates.** A deterministic, fully-tested engine
computes every signal *and* the verdict; the on-device LLM only (a) classifies coarse
effort tiers from the user's own assignment content and (b) phrases the already-computed
facts into a friendly heads-up. The feature must work with AI off, via a heuristic +
templated fallback. A hallucinated "you're failing" verdict would destroy trust, so the
model never touches numbers or the verdict.

## Scope decisions (from brainstorming)

- **Three signals:** deadline risk (high-value work due soon, not submitted); missing/
  ungraded pileup (past-due-not-submitted, share of grade unearned); start-by nudge
  (`shouldHaveStarted` / `startSoon`). **No grade projection.**
- **No user target/goal.** Pure risk signals, no goal-setting UI.
- **One merged section**, per-course, in CourseDetail — blends anticipatory + reactive
  into one prioritized heads-up.
- **Effort estimate** (drives the start-by date) = deterministic heuristic baseline +
  optional on-device-AI refinement. Coarse tiers only (quick / moderate / substantial),
  never false precision. Framed as a soft suggestion.

## Architecture (mirrors the existing `calculatorInputs` → `GradeCalculator` split)

1. **Assembly** — `CanvasRepository.riskInputs(courseId:)` in
   `Sources/CanvasData/DerivedReads.swift` (or a sibling), reading cached rows exactly
   like `calculatorInputs` / `stream` already do. Reuses `CachedAssignment`
   (`pointsPossible`, `dueAt`, `groupId`, `lockAt`, `submissionTypes`), `CachedSubmission`
   (`workflowState`, `missing`, `late`, `submittedAt`, `excused`, `score`),
   `CachedAssignmentGroup` (`groupWeight`), and the same duplicate-safe uniquing as `stream`.

2. **Effort estimate (deterministic baseline)** — `Sources/CanvasCore/EffortEstimator.swift`.
   Pure `CachedAssignment metadata → EffortTier` (`.quick`/`.moderate`/`.substantial`)
   from points, submission types, rubric criteria count, description length. Each tier →
   a lead time (e.g. 1 / 3 / 7 days). Always available, testable.

3. **Pure logic** — `Sources/CanvasCore/PacingEngine.swift`. `Sendable`, no I/O,
   deterministic. Takes assembled inputs + a resolved effort tier per assignment
   (heuristic default or AI-refined override). Computes `CourseRiskSignals`:
   - `pastDueNotSubmitted` — `dueAt < now`, not excused, no submission / `unsubmitted` /
     `missing`. (Skip locked/unavailable.)
   - `dueSoon` — `dueAt` within a window (default 7 days), not submitted, urgency-sorted;
     "high-stakes" when points or group weight is large.
   - `startBy` per not-yet-started assignment = `dueAt − leadTime(effortTier)`; emit
     `shouldHaveStarted` (now ≥ startBy) and `startSoon`.
   - `unearnedShare` — fraction of graded-category points still unearned.
   - `level: RiskLevel` (`.clear`/`.watch`/`.behind`) — decided here deterministically.

4. **AI effort refinement (optional)** — `EffortClassifier` protocol + Foundation Models
   impl. `classify(_ assignment) async -> EffortTier` reads description + rubric (user's
   own content). Where `SystemLanguageModel.default.availability == available`, ViewModel
   classifies async and recomputes with refined tiers; else heuristic tiers stand.

5. **AI narration (optional)** — `PacingNarrator` protocol + Foundation Models impl.
   `narrate(_ signals) async -> String`. Availability-gated; background `Task`; tiny
   input; `@Generable` optional for a two-line headline/detail; any error → deterministic
   templated fallback. AI never sets `level`.

6. **UI** — `CoursePacingSection` SwiftUI view, one merged section in the CourseDetail
   workspace. Always renders deterministic signals as chips/rows; narration string on top
   with the fallback shown while it loads. Extend `CourseDetailViewModel` with
   `@Published var riskSignals` + `@Published var pacingBlurb`; `readFromStore` computes
   signals instantly (heuristic tiers), a follow-up async task refines + narrates.

## Critical files

- New: `Sources/CanvasCore/PacingEngine.swift`, `Sources/CanvasCore/EffortEstimator.swift`,
  `Sources/CanvasCore/PacingInputs.swift` (or folded in).
- Edit: `Sources/CanvasData/DerivedReads.swift` — add `riskInputs(courseId:now:)`.
- New: `CanvasApp/.../EffortClassifier.swift`, `CanvasApp/.../PacingNarrator.swift`,
  `CanvasApp/Views/.../CoursePacingSection.swift`.
- Edit: `CanvasApp/ViewModels/CourseDetailViewModel.swift`; mount in CourseWorkspace/detail view.
- New tests: `Tests/CanvasCoreTests/PacingEngineTests.swift`.

## Verification

1. Unit tests (deterministic core): fixtures → assert exact `CourseRiskSignals`
   (past-due count, due-soon set, `startBy`/`shouldHaveStarted`, `level`); cover excused,
   late-but-submitted, locked, no due date, weighted vs unweighted. Separately test
   `EffortEstimator`. Run per-filter (`swift test --filter PacingEngineTests`) — the full
   suite deadlocks at the first SwiftData suite.
2. Fallback paths: force `availability == unavailable` / inject stubs; assert heuristic
   tiers drive `startBy`, templated narration renders, `level` unchanged.
3. Device smoke test on an Apple-Intelligence device; toggle Apple Intelligence off,
   confirm graceful fallback.

## Design notes

- Due-soon window: 7 days. Effort→lead-time: quick 1d / moderate 3d / substantial 7d.
- `RiskLevel` thresholds: start simple (any past-due or `shouldHaveStarted` → `.watch`;
  2+ past-due or high-stakes item due <48h → `.behind`), tune against real data.
- Visual language (from the mockup): "Paper & Signal" tokens; severity uses the muted
  warm grade palette (clay/ochre/green); orchid reserved for the anticipatory "get a head
  start" / on-device-intelligence signal.
