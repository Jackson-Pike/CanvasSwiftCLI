# Onboarding — Demo-First First-Run Design

**Date:** 2026-07-04
**Status:** Draft (awaiting user review)
**Scope:** First-run onboarding for the CanvasApp MenuBarExtra popover (380×520).

## Problem

The current first-run funnel forces the user to obtain and paste a real Canvas
API token before they can see anything, and it shows the Keychain-password
explanation screen to *everyone* — including people who just want to look around.
Demo mode (`token == "DEMO"` short-circuits `APIClient` to `MockData`) already
exists but is surfaced nowhere in the UI. A person who installs from the public
GitHub release and has no Canvas token hits a dead end.

## Goal

A polished first-run experience where anyone can explore the app instantly via a
demo, or connect a real Canvas account — sized appropriately for a small menu-bar
popover. No multi-screen feature "tour" (YAGNI for this surface).

## Current funnel (before)

`PopoverContent` gates on flags, in order:

1. `!hasSeenIntro` → **WelcomeView** (consent/disclosures) → `completeIntro()`
2. `!hasAcknowledgedKeychain` → **KeychainWarningView** → `acknowledgeKeychain()`
3. `!hasToken` → **SettingsView(isOnboarding: true)** (token entry) → `saveToken()`
4. else → **CourseListView**

Problem: step 2 (Keychain warning) is shown before the user has even decided
whether they need the Keychain at all.

## New funnel (after)

```
!hasSeenIntro            → WelcomeView            → "Get Started" → completeIntro()
!hasToken (and !isDemo)  → ConnectView (NEW)      → branch:
                                                     ├─ real token → KeychainWarning → save
                                                     └─ "Try the demo" → enterDemo()
else                     → CourseListView
```

`hasAcknowledgedKeychain` is removed from the top-level gate. The Keychain
explanation is now shown only on the real-token branch, immediately before the
token is written to the Keychain.

## Components

### ConnectView (new) — replaces SettingsView as the onboarding entry
- Title: "Connect to Canvas".
- `SecureField` for the token + helper text "Find this in Canvas → Account →
  Settings → New Access Token", with a link/button that opens the Canvas access-
  token page in the browser.
- **Primary** button "Connect" (disabled until the field is non-empty). Tapping
  it presents `KeychainWarningView` (as a step/sheet); its "Continue" calls
  `appState.saveToken(...)` (which writes the Keychain) and dismisses.
- Divider labelled "or".
- **Secondary** button "Try the demo" → `appState.enterDemo()`. Subtext: "Explore
  with sample data — no Canvas account needed."

### KeychainWarningView (reused, relocated)
- Content unchanged. No longer shown by the top-level gate; presented only from
  the real-token branch of `ConnectView`, right before saving.
- Its action calls `saveToken` + `acknowledgeKeychain()` together.

### SettingsView (non-onboarding) — demo affordance
- When `appState.isDemo`: show a "Demo mode" badge and a "Connect your Canvas
  account" affordance (reveals the token field) so a demo user can upgrade to a
  real token. Saving a real token clears demo mode.
- When real token: existing token-update field (unchanged).
- `isOnboarding` parameter and the onboarding branch of `SettingsView` are
  removed (that role moves to `ConnectView`).

### AppState — demo state
- New `@Published var isDemo: Bool`, persisted under UserDefaults key
  `"isDemoMode"`.
- `func enterDemo()`:
  - sets `isDemo = true`, persists the flag,
  - sets `token = "DEMO"` **without** calling `KeychainHelper.save` (no Keychain
    prompt),
  - does not touch `hasAcknowledgedKeychain`.
- `saveToken(_:)` (real token path): additionally clears `isDemo` (and its flag)
  so upgrading from demo to a real token exits demo mode.
- `init()` restore order:
  - if `isDemo` flag set → `token = "DEMO"`,
  - else if `hasAcknowledgedKeychain` → `token = KeychainHelper.load()`.
- `hasToken` already treats `"DEMO"` as a non-empty token → routes to
  `CourseListView`. `makeClient()` builds `APIClient(token: "DEMO")`, which the
  existing short-circuit resolves to `MockData`.

## Data flow

- Demo: `enterDemo()` → `token = "DEMO"` → `CourseListView` → `makeClient()` →
  `APIClient(token:"DEMO")` → `MockData.*`. Nothing hits the network or Keychain.
- Real: `ConnectView` → `KeychainWarningView.Continue` → `saveToken` (Keychain
  write, `isDemo` cleared) → `CourseListView` → live Canvas API.

## Error handling / edge cases

- Relaunch in demo mode: restored from the `isDemoMode` flag; no Keychain access.
- Demo → real upgrade via Settings: `saveToken` clears demo flag and writes the
  Keychain (first real Keychain write triggers the one-time prompt).
- Token normalization (trim, strip `Bearer `) stays in `saveToken` — unchanged.
- A user who typed "DEMO" as a real token in the field still lands in demo data
  (acceptable; it's the documented sentinel).

## Testing

- `AppStateTests` (new, `@MainActor`):
  - `enterDemo()` sets `token == "DEMO"`, `isDemo == true`, and performs **no**
    Keychain write (verifiable via the DEBUG UserDefaults-backed `KeychainHelper`).
  - `saveToken("abc")` sets `isDemo == false` and writes the token.
  - init restores demo from the `isDemoMode` flag.
- `APIClientDemoTests` already verifies `DEMO → MockData`; no change needed.
- Manual: fresh launch (reset UserDefaults) → Welcome → ConnectView → "Try the
  demo" → course list with sample data, no Keychain prompt.

## Out of scope

- Multi-screen guided feature tour / coach marks.
- Any change to `MockData` contents.
- Signing/notarization (tracked separately with the release work).
