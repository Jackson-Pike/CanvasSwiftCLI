# Keychain Onboarding UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insert a friendly Keychain-warning interstitial between WelcomeView and SettingsView, defer all Keychain access until the user taps "Continue," and eliminate the double-prompt on save.

**Architecture:** Four targeted changes — fix `KeychainHelper` to use an upsert pattern with friendly metadata, update `AppState` to load the token lazily via a new `acknowledgeKeychain()` method, create `KeychainWarningView` as a new interstitial screen, and add a new branch to `PopoverContent` in `CanvasApp.swift`.

**Tech Stack:** Swift 5.9+, SwiftUI, Security framework (`SecItem*` APIs), macOS 13+

## Global Constraints

- UI copy must match spec verbatim (heading, body, caption, button label).
- Button tint: `Color.byuhRed` (already defined in `BrandColors.swift`).
- UserDefaults key for new flag: `"hasAcknowledgedKeychain"`.
- Keychain label: `"Canvas Grades – API Token"`, description: `"Canvas LMS API token for reading grades"`.
- No unit test target exists for the `CanvasApp` Xcode target — all verification is manual (run in Xcode or via the `canvas` CLI shim).
- Do not modify any file in `Sources/CanvasCore/` or `Tests/`.

---

## File Map

| File | Action |
|------|--------|
| `CanvasApp/App/KeychainHelper.swift` | Modify — upsert save, add metadata |
| `CanvasApp/App/AppState.swift` | Modify — lazy token init, new flag + method |
| `CanvasApp/Views/KeychainWarningView.swift` | Create — new interstitial screen |
| `CanvasApp/App/CanvasApp.swift` | Modify — add KeychainWarningView branch |

---

### Task 1: Fix KeychainHelper — upsert save and friendly metadata

**Files:**
- Modify: `CanvasApp/App/KeychainHelper.swift`

**Interfaces:**
- Produces: `KeychainHelper.save(token:)` uses upsert; `KeychainHelper.load()` unchanged in signature; Keychain items carry `kSecAttrLabel` and `kSecAttrDescription`.

- [ ] **Step 1: Replace the save implementation**

Replace the entire contents of `CanvasApp/App/KeychainHelper.swift` with:

```swift
import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.byuh.CanvasApp"
    private static let account = "canvas_token"
    private static let label = "Canvas Grades – API Token"
    private static let itemDescription = "Canvas LMS API token for reading grades"

    static func save(token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrLabel: label,
            kSecAttrDescription: itemDescription
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addAttrs = query
            addAttrs[kSecValueData] = data
            addAttrs[kSecAttrLabel] = label
            addAttrs[kSecAttrDescription] = itemDescription
            SecItemAdd(addAttrs as CFDictionary, nil)
        }
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Build to confirm no compile errors**

In Xcode: Product → Build (⌘B), or run `xcodebuild -project CanvasCLISwift.xcodeproj -scheme CanvasApp build` and confirm `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/App/KeychainHelper.swift
git commit -m "fix: upsert Keychain save to eliminate double-prompt; add friendly item metadata"
```

---

### Task 2: Update AppState — lazy token load and acknowledgement flag

**Files:**
- Modify: `CanvasApp/App/AppState.swift`

**Interfaces:**
- Consumes: `KeychainHelper.load()` (from Task 1)
- Produces:
  - `AppState.hasAcknowledgedKeychain: Bool` — `@Published`, UserDefaults-backed
  - `AppState.acknowledgeKeychain()` — sets flag to `true`, calls `KeychainHelper.load()`, assigns to `token`

- [ ] **Step 1: Update AppState**

Replace the entire contents of `CanvasApp/App/AppState.swift` with:

```swift
import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = nil
    @Published var showingSettings = false
    @Published var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")
    @Published var hasAcknowledgedKeychain: Bool = UserDefaults.standard.bool(forKey: "hasAcknowledgedKeychain")

    let hiddenCoursesStore: HiddenCoursesStore
    let coursesVM: CoursesViewModel
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    init() {
        let store = HiddenCoursesStore()
        hiddenCoursesStore = store
        coursesVM = CoursesViewModel(hiddenStore: store)
        if UserDefaults.standard.bool(forKey: "hasAcknowledgedKeychain") {
            token = KeychainHelper.load()
        }
    }

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        var trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(token: trimmed)
        token = trimmed
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func acknowledgeKeychain() {
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedKeychain")
        hasAcknowledgedKeychain = true
        token = KeychainHelper.load()
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(token: token)
    }

    func detailViewModel(for course: Course) -> CourseDetailViewModel {
        if let existing = detailVMs[course.id] { return existing }
        let vm = CourseDetailViewModel(course: course)
        detailVMs[course.id] = vm
        return vm
    }
}
```

> **Note on the `init`:** Returning users (who already acknowledged Keychain on a previous launch) skip the warning screen and have their token loaded immediately, preserving the current UX for non-first-time users.

- [ ] **Step 2: Build to confirm no compile errors**

Product → Build (⌘B). Confirm `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/App/AppState.swift
git commit -m "feat: lazy-load Keychain token; add hasAcknowledgedKeychain flag and acknowledgeKeychain()"
```

---

### Task 3: Create KeychainWarningView

**Files:**
- Create: `CanvasApp/Views/KeychainWarningView.swift`

**Interfaces:**
- Consumes: `AppState.acknowledgeKeychain()` (from Task 2), `Color.byuhRed` (already in `BrandColors.swift`)
- Produces: `KeychainWarningView` — a SwiftUI `View` struct usable in `PopoverContent`

- [ ] **Step 1: Create the view file**

Create `CanvasApp/Views/KeychainWarningView.swift` with:

```swift
import SwiftUI

struct KeychainWarningView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)

                Text("One quick thing")
                    .font(.title2.bold())

                Text("macOS will ask for your Keychain password to securely store your Canvas API token. This only happens once — your token stays on this Mac and is never sent anywhere.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Text("If macOS asks 'Allow CanvasApp to use your confidential information,' tap Always Allow.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                Button {
                    appState.acknowledgeKeychain()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.byuhRed)
                .controlSize(.large)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 28)
        }
    }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, right-click the `Views` group → Add Files → select `KeychainWarningView.swift`. Confirm the `CanvasApp` target is checked.

- [ ] **Step 3: Build to confirm no compile errors**

Product → Build (⌘B). Confirm `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/Views/KeychainWarningView.swift
git commit -m "feat: add KeychainWarningView interstitial screen"
```

---

### Task 4: Wire KeychainWarningView into PopoverContent and verify full flow

**Files:**
- Modify: `CanvasApp/App/CanvasApp.swift`

**Interfaces:**
- Consumes: `KeychainWarningView` (Task 3), `AppState.hasAcknowledgedKeychain` (Task 2)

- [ ] **Step 1: Update PopoverContent**

Replace the entire contents of `CanvasApp/App/CanvasApp.swift` with:

```swift
import SwiftUI
import CanvasCore

@main
struct CanvasApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environmentObject(appState)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PopoverContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.hasSeenIntro {
            WelcomeView()
                .environmentObject(appState)
        } else if !appState.hasAcknowledgedKeychain {
            KeychainWarningView()
                .environmentObject(appState)
        } else if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
                .environmentObject(appState.hiddenCoursesStore)
        } else {
            NavigationStack {
                CourseListView(vm: appState.coursesVM)
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
                    .environmentObject(appState.hiddenCoursesStore)
            }
        }
    }
}
```

- [ ] **Step 2: Build to confirm no compile errors**

Product → Build (⌘B). Confirm `BUILD SUCCEEDED`.

- [ ] **Step 3: Reset onboarding state and verify first-launch flow**

In Terminal, reset the UserDefaults flags so the app starts fresh:

```bash
defaults delete com.byuh.CanvasApp hasSeenIntro 2>/dev/null; \
defaults delete com.byuh.CanvasApp hasAcknowledgedKeychain 2>/dev/null; \
true
```

Also delete the Keychain item if one exists (open Keychain Access → search "Canvas Grades" → delete, or run `security delete-generic-password -s com.byuh.CanvasApp`).

Then run the app and verify:
- App opens to **WelcomeView** — no Keychain prompt appears.
- Tap "Get Started" → advances to **KeychainWarningView** — no Keychain prompt appears yet.
- Tap "Continue" → macOS Keychain dialog appears. The dialog should reference `"Canvas Grades – API Token"` (visible in Keychain Access after granting). Tap "Always Allow."
- App advances to **SettingsView (onboarding)** — enter a Canvas token and tap Save. Only one Keychain prompt should appear (or none if "Always Allow" was clicked).
- App advances to **CourseListView**.

- [ ] **Step 4: Verify returning-user flow**

Quit and relaunch the app (without resetting flags). Confirm:
- No Keychain prompt on launch (already acknowledged).
- App goes directly to **CourseListView** (token already stored).

- [ ] **Step 5: Commit**

```bash
git add CanvasApp/App/CanvasApp.swift
git commit -m "feat: gate startup flow on hasAcknowledgedKeychain; wire in KeychainWarningView"
```
