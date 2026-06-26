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
        if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
        } else {
            NavigationStack {
                CourseListView()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { appState.showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
            }
        }
    }
}
