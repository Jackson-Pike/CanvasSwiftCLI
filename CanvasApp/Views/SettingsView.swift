import SwiftUI

struct SettingsView: View {
    let isOnboarding: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hiddenStore: HiddenCoursesStore
    @State private var tokenInput = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Text(isOnboarding ? "Welcome to Canvas" : "Settings")
                        .font(.headline)
                    if !isOnboarding {
                        HStack {
                            Spacer()
                            Button {
                                appState.navigationPath.removeLast()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Canvas API Token")
                        .font(.subheadline).foregroundStyle(.secondary)
                    SecureField("Paste token here…", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                    Text("Find this in Canvas → Account → Settings → New Access Token")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Button("Save") {
                    appState.saveToken(tokenInput)
                    if !isOnboarding { appState.navigationPath.removeLast() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.byuhRed)
                .disabled(tokenInput.isEmpty)

                if !hiddenStore.hiddenIDs.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hidden Courses")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(Array(hiddenStore.hiddenIDs).sorted(), id: \.self) { courseId in
                            HStack {
                                let name = appState.coursesVM.allFetchedCourses
                                    .first { $0.id == courseId }?.courseCode
                                    ?? "Course \(courseId)"
                                Text(name).font(.subheadline)
                                Spacer()
                                Button("Restore") { hiddenStore.restore(courseId) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 340)
    }
}
