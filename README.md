# Canvas Grades

A lightweight macOS **menu-bar app** for checking your Canvas grades at a glance —
course grades, recent feedback, and a "what-if" calculator for figuring out the
scores you need. Built with SwiftUI, everything stays on your Mac.

> **Unofficial.** Canvas Grades is an independent tool and is not affiliated with,
> endorsed by, or connected to Instructure, Inc. or the Canvas LMS.

> **Note:** the Canvas host is currently set to **BYU–Hawaii**
> (`byuh.instructure.com`). Other institutions aren't supported yet.

## Features

- **Menu-bar access** — grades live in a popover from your menu bar, no window to
  manage.
- **Course grade cards** — current grade per active course.
- **Activity stream** — per course: awaiting-grade, upcoming, recently graded, and
  recent instructor feedback.
- **What-If calculator** — enter hypothetical scores to see your projected grade,
  or solve for the score you need to hit a target letter/percentage.
- **Demo mode** — explore the whole app with realistic sample data, no Canvas
  account required.
- **Private by design** — your API token is stored in the macOS Keychain, and
  grade data is fetched directly from Canvas. Nothing is sent to any third party.

## Requirements

- macOS 14 (Sonoma) or later
- A Canvas account at BYU–Hawaii (or use **Demo mode** to try it out)

## Install

### Homebrew (coming soon)

```sh
brew install --cask canvas-grades
```

### Download

Grab the latest `.dmg` from the [Releases](../../releases) page, open it, and drag
**Canvas Grades** to Applications.

> The app is currently **unsigned**. On first launch macOS Gatekeeper will warn
> you. Right-click the app → **Open** → **Open**, or run:
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Canvas Grades.app"
> ```

## Getting a Canvas API token

1. Log in to Canvas → **Account → Settings**.
2. Under **Approved Integrations**, click **+ New Access Token**.
3. Give it a purpose (e.g. "Canvas Grades") and generate it.
4. Copy the token and paste it into the app's connect screen.

Prefer not to? Choose **Try the demo** on first launch to explore with sample data.

## Build from source

```sh
git clone https://github.com/Jackson-Pike/CanvasSwiftCLI.git
cd CanvasSwiftCLI
swift build
swift test        # 43 tests
```

Open `CanvasCLISwift.xcodeproj` in Xcode to run the app target.

## Project layout

| Path | What it is |
|------|-----------|
| `Sources/CanvasCore` | Networking (`APIClient`), models, grade math, mock data |
| `CanvasApp` | SwiftUI menu-bar app (views, view models, app state) |
| `Tests/CanvasCoreTests` | Unit tests for the core library |

## Privacy

Your Canvas API token is stored only in your Mac's Keychain. Grade data is
requested directly from Canvas over HTTPS and rendered locally — there is no
backend server and no analytics.

## License

_TBD._
