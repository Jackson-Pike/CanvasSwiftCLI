import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@main
struct CanvasGradesApp: App {
    @State private var session = AppSession()
    @State private var router = Router()
    @AppStorage("appearance") private var appearance: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environment(session)
                .environment(router)
                .frame(width: 380, height: 520)
                .preferredColorScheme(preferredColorScheme)
        }
        .menuBarExtraStyle(.window)

        Window("Canvas", id: "main") {
            MainWindowView()
                .environment(session)
                .environment(router)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 1000, height: 700)
    }
}

struct PopoverContent: View {
    @Environment(AppSession.self) private var session
    @State private var path = NavigationPath()

    private var coursesVM: CoursesViewModel { session.coursesVM }

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
