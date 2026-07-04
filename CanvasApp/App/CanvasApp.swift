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
            NavigationStack(path: $appState.navigationPath) {
                CourseListView(vm: appState.coursesVM)
                    .navigationDestination(for: String.self) { destination in
                        if destination == "settings" {
                            SettingsView(isOnboarding: false)
                                .environmentObject(appState)
                                .environmentObject(appState.hiddenCoursesStore)
                        }
                    }
            }
        }
    }
}
