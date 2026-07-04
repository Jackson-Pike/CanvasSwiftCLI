# Keychain Onboarding UX — Design Spec

**Date:** 2026-06-26  
**Status:** Approved  

---

## Problem

On first launch, the macOS Keychain permission dialog appears before the user has seen any in-app UI. The dialog references the internal identifier `"canvas_token"`, which is unfamiliar and alarming. Additionally, the current `save()` implementation uses `SecItemDelete` + `SecItemAdd`, which can trigger two separate system prompts in quick succession.

---

## Goals

1. Delay the Keychain prompt until the user has explicitly acknowledged it.
2. Warn the user with friendly in-app copy before the system dialog appears.
3. Improve the text shown in the system dialog via Keychain item metadata.
4. Eliminate the double-prompt on save.

---

## Flow

```
[WelcomeView]
    ↓ "Get Started" → appState.completeIntro()
[KeychainWarningView]   ← new
    ↓ "Continue" → appState.acknowledgeKeychain()  (triggers KeychainHelper.load())
[SettingsView (isOnboarding: true)]
    ↓ token saved
[CourseListView]
```

State is gated in `PopoverContent` by three boolean flags checked in order:
1. `!hasSeenIntro` → `WelcomeView`
2. `!hasAcknowledgedKeychain` → `KeychainWarningView`
3. `!hasToken` → `SettingsView(isOnboarding: true)`
4. else → `CourseListView`

---

## Components

### `KeychainWarningView` (new file)

A single-screen interstitial with no back navigation.

**Layout:**
- `lock.shield.fill` SF Symbol, large, green — centered, upper area
- Heading: `"One quick thing"`
- Body paragraph: `"macOS will ask for your Keychain password to securely store your Canvas API token. This only happens once — your token stays on this Mac and is never sent anywhere."`
- Caption (tertiary): `"If macOS asks 'Allow CanvasApp to use your confidential information,' tap Always Allow."`
- Full-width primary button: `"Continue"` (byuhRed)

Tapping "Continue" calls `appState.acknowledgeKeychain()`.

### `AppState` changes

- `token` initializes to `nil` — no eager Keychain read on launch.
- New `@Published var hasAcknowledgedKeychain: Bool` backed by `UserDefaults` key `"hasAcknowledgedKeychain"`.
- New method `acknowledgeKeychain()`:
  ```swift
  func acknowledgeKeychain() {
      UserDefaults.standard.set(true, forKey: "hasAcknowledgedKeychain")
      hasAcknowledgedKeychain = true
      token = KeychainHelper.load()
  }
  ```

### `KeychainHelper` changes

**Improved item metadata** — add to both `SecItemAdd` attributes and `SecItemCopyMatching` query:
```swift
kSecAttrLabel: "Canvas Grades – API Token"
kSecAttrDescription: "Canvas LMS API token for reading grades"
```

**Fix double-prompt on save** — replace `SecItemDelete` + `SecItemAdd` with an upsert pattern:
```swift
static func save(token: String) {
    let data = Data(token.utf8)
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account
    ]
    let attributes: [CFString: Any] = [
        kSecValueData: data,
        kSecAttrLabel: "Canvas Grades – API Token",
        kSecAttrDescription: "Canvas LMS API token for reading grades"
    ]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
        var addAttrs = query
        addAttrs[kSecValueData] = data
        addAttrs[kSecAttrLabel] = "Canvas Grades – API Token"
        addAttrs[kSecAttrDescription] = "Canvas LMS API token for reading grades"
        SecItemAdd(addAttrs as CFDictionary, nil)
    }
}
```

### `CanvasApp.swift` changes

Update `PopoverContent.body` to add the `KeychainWarningView` branch between `WelcomeView` and `SettingsView`.

---

## Files Changed

| File | Change |
|------|--------|
| `CanvasApp/Views/KeychainWarningView.swift` | New file |
| `CanvasApp/App/AppState.swift` | Lazy token load, new flag + method |
| `CanvasApp/App/KeychainHelper.swift` | Upsert save, improved metadata |
| `CanvasApp/App/CanvasApp.swift` | New branch in PopoverContent |

---

## Out of Scope

- Biometric/FaceID Keychain access (`kSecAccessControl`) — not needed for this app.
- Keychain sharing between app extensions.
- Migration of existing Keychain items for users upgrading from a previous build (the upsert pattern handles this transparently).
