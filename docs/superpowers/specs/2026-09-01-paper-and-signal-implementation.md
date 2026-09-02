# Paper & Signal — Implementation Plan

**Status:** direction approved 2026-09-01, not yet implemented.
**Design reference (living, theme-aware):** https://claude.ai/code/artifact/4326446a-a32b-48c1-8ccd-ee7665724dd3
**Full direction + rationale:** auto-memory `project_design_direction.md` (indexed in `MEMORY.md`).

Reshapes `Sources/CanvasUI/DesignTokens.swift` + `Sources/CanvasUI/BrandColors.swift` and the view sites that ride the accent. Each step ships independently.

## Direction in one line
Warm editorial grade ledger ("Paper & Signal"): warm paper/charcoal grounds, hairlines not cards, New York serif for display numerals, SF Mono for figures, and **one orchid signal that owns every interactive/selected state**. Raycast + Monocle DNA; Bloom warmth as a seasoning only.

## Chosen values
- **Accent (orchid):** light `#8C43B0`, dark `#C089E0`. (Warmed from the old blue-violet `#5A4FCF`/`#7A6EFF`; deliberately red-violet, stopped short of orange so it never blurs into the clay-red D/F danger tone.)
- Neutrals, inks, grade spectrum, course palette: see `project_design_direction.md` and the reference artifact's token map (section 01 + section 05).

---

## Step 1 — Route the accent, delete blue (DO THIS FIRST)

**Goal:** orchid owns every interactive/selected state; system blue and chrome `byuhRed` gone.

### 1a. Set the token to orchid
`Sources/CanvasUI/DesignTokens.swift` ~L84–87, `accentHypothetical`:
- light `#5A4FCF` → `#8C43B0`
- dark  `#7A6EFF` → `#C089E0`

> Note: the token name `accentHypothetical` is now doing double duty as the app's primary signal. Renaming to `accentSignal` is reasonable but a wider refactor — defer unless cheap.

### 1b. Key subtlety — `.tint()` vs `Color.accentColor`
- A root `.tint(Color.accentHypothetical)` makes **system controls, focus rings, List selection, and `.foregroundStyle(.tint)`** adopt orchid. Add it at the scene root in **both** scenes in `CanvasApp/App/CanvasApp.swift`: the `Window("Canvas")` content (`MainWindowView`) and the `MenuBarExtra` `PopoverContent`.
- BUT `Color.accentColor` used as a **static color value** (e.g. `.background(Color.accentColor)`, `.foregroundStyle(Color.accentColor)`) does **not** follow `.tint` and there is no AccentColor asset in this SPM app → it resolves to system blue. These must be replaced with `Color.accentHypothetical` directly.

### 1c. Sites to re-point (from grep 2026-09-01)
Replace `Color.accentColor` / `.accentColor` → `Color.accentHypothetical`:
- `Sources/CanvasUI/CalendarComponents.swift` L156, L165, L239, L251, L320, L328 (isToday background + course-color fallback)
- `Sources/CanvasUI/QuickOpenView.swift` L20, L22, L49 (⌘K selection — high visibility)
- `Sources/CanvasUI/FileComponents.swift` L115, L121, L126
- `Sources/CanvasUI/ToDoComponents.swift` L78 (default param)
- `CanvasApp/Views/Window/ToDoView.swift` L98, L102
- `CanvasApp/Views/Window/FilesTabView.swift` L70

Replace literal `.blue`:
- `Sources/CanvasUI/FileComponents.swift` L156 (file-type color fallback)
- `Sources/CanvasUI/ModuleComponents.swift` L82 (module item fallback)
- `Sources/CanvasUI/CalendarComponents.swift` L45 (default `courseColor` param)
- `Sources/CanvasUI/BrandColors.swift` L17 `courseAccentPalette` (full replacement — Step 4, but the `.blue` leaves here)
- `CanvasApp/ViewModels/DashboardViewModel.swift` L145 & `CanvasApp/Views/Window/MainWindowView.swift` L145 — `hues` arrays for course colors (align with Step 4 palette)

Chrome `byuhRed` tint (direction retires byuhRed from chrome) → `Color.accentHypothetical`:
- `CanvasApp/Views/WelcomeView.swift` L60, `CanvasApp/Views/CourseListView.swift` L67, `CanvasApp/Views/KeychainWarningView.swift` L45, `CanvasApp/Views/Window/DashboardView.swift` L117, `CanvasApp/Views/SettingsView.swift` L141
- (Onboarding red is a defensible separate call — confirm with user if unsure, but default is orchid.)

Leave alone: `.tint(Color.accentHypothetical)` sites already correct (`SandboxRail.swift`, `TermSandboxRail.swift`); `.tint(Color.letterGradeColor(...))` in `GradeDashboard.swift` L66 (semantic, intentional).

### 1d. Verify
```
bash scripts/run-app.sh          # builds + launches the .app bundle
```
Launch straight into DEMO (main window opens from the menu-bar graduation-cap popover, not at launch):
```
defaults write com.byuh.CanvasApp dev_canvas_token.byuh.instructure.com -string DEMO
defaults write com.byuh.CanvasApp canvasHost -string byuh.instructure.com
defaults write com.byuh.CanvasApp hasSeenIntro -bool true
defaults write com.byuh.CanvasApp hasAcknowledgedKeychain -bool true
```
Check: sidebar selection, Calendar "today", ⌘K selection, To-Do/Files accents, segmented pills all read **orchid** in light and dark — zero system blue. (Screen-recording perms aren't granted to the agent process; have the user capture, or grant Screen Recording to the terminal.)
Then `graphify update .`.

---

## Steps 2–5 (summary; detail when reached)
2. **Display font role** — `Font.display` → `.system(size:, design:.serif)` (New York); add small-caps `sectionLabel`; start replacing tracked ALL-CAPS labels.
3. **Neutrals + inks + dark elevation** — re-value `canvasBG`/`canvasPanel`, add `canvasRaised`, warm/neutralize the lavender-tinted dark inks. (Values in artifact token map.)
4. **Grade + course colors** — replace `letterGradeColor` (drop Google Material) and `courseAccentPalette` with the muted warm set; retire `byuhRed` from chrome entirely.
5. **Flatten cards → hairlines** — Calendar month cells (`CalendarComponents.swift`) and list rows; cut all-caps labels to the chosen few.

## HIG guardrails
Respect: NavigationSplitView, real controls, SF Pro UI, Dynamic Type, light/dark, sidebar selection semantics. Bend deliberately: custom accent, New York serif display, hairline rows over default `List` chrome. Don't: faux-web shadows/gradients everywhere; trading grade-status legibility for prettiness; keep the "→" button arrows (drop them — motion says what changed).
