import SwiftUI
import CanvasUI

struct SettingsView: View {
    let isOnboarding: Bool
    @ObservedObject var vm: CoursesViewModel
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
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
                                dismiss()
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
                    session.saveCredentials(host: session.host, token: tokenInput)
                    if !isOnboarding { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.byuhRed)
                .disabled(tokenInput.isEmpty)

                let hidden = vm.hiddenCourses(session: session)
                if !hidden.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hidden Courses")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(hidden, id: \.id) { course in
                            HStack {
                                Text(course.courseCode).font(.subheadline)
                                Spacer()
                                Button("Restore") { vm.restore(courseId: course.id, session: session) }
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
