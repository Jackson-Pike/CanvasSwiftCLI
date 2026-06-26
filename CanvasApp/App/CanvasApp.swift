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
        } else if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
        } else {
            NavigationStack {
                CourseListView(vm: appState.coursesVM)
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
            }
        }
    }
}
