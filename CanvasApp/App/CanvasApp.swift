import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@main
struct CanvasGradesApp: App {
    @State private var session = AppSession()
    @State private var router = Router()

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environment(session)
                .environment(router)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PopoverContent: View {
    @Environment(AppSession.self) private var session
    @StateObject private var coursesVM = CoursesViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        if !session.hasSeenIntro {
            WelcomeView()
        } else if !session.hasAcknowledgedKeychain {
            KeychainWarningView()
        } else if !session.hasCredentials {
            SettingsView(isOnboarding: true, vm: coursesVM)
        } else {
            NavigationStack(path: $path) {
                CourseListView(vm: coursesVM, path: $path)
                    .navigationDestination(for: String.self) { destination in
                        if destination == "settings" {
                            SettingsView(isOnboarding: false, vm: coursesVM)
                        }
                    }
            }
        }
    }
}
