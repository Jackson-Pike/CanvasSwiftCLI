import SwiftUI

struct SettingsView: View {
    let isOnboarding: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hiddenStore: HiddenCoursesStore
    @State private var tokenInput = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(isOnboarding ? "Welcome to Canvas" : "Settings")
                .font(.headline)
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
                if !isOnboarding { dismiss() }
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
        .frame(width: 340)
    }
}
