import SwiftUI
import CanvasUI
import CanvasCore

struct SettingsView: View {
    let isOnboarding: Bool
    @ObservedObject var vm: CoursesViewModel
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""
    @State private var tokenInput = ""
    @State private var testState: TestState = .idle
    @State private var confirmHostChange = false

    enum TestState: Equatable {
        case idle, testing
        case success(name: String)
        case failure(message: String)
    }

    private var normalizedHost: String? { Credentials.normalizeHost(hostInput) }

    private var canTestConnection: Bool {
        normalizedHost != nil && !tokenInput.isEmpty
    }

    private var canSave: Bool {
        if case .success = testState { return true }
        return false
    }

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
                    Text("Canvas Host")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField("canvas.school.edu", text: $hostInput)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: hostInput) { testState = .idle }
                    Text("Your school's Canvas domain")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if !hostInput.isEmpty && normalizedHost == nil {
                        Text("Not a valid hostname")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Canvas API Token")
                        .font(.subheadline).foregroundStyle(.secondary)
                    SecureField("Paste token here…", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: tokenInput) { testState = .idle }
                    Text("Find this in Canvas → Account → Settings → New Access Token")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Button("Test Connection") {
                    guard let normalized = normalizedHost else { return }
                    let trimmedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    testState = .testing
                    Task {
                        let result = await session.testConnection(host: normalized, token: trimmedToken)
                        switch result {
                        case .success(let profile):
                            testState = .success(name: profile.name)
                        case .failure(let error):
                            let message = (error as? APIError)?.description ?? error.localizedDescription
                            testState = .failure(message: message)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canTestConnection)

                switch testState {
                case .idle:
                    EmptyView()
                case .testing:
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Testing…").font(.caption).foregroundStyle(.secondary)
                    }
                case .success(let name):
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Connected as **\(name)**").font(.caption)
                    }
                case .failure(let message):
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Button("Save") {
                    guard let normalized = normalizedHost else { return }
                    let hostChanged = normalized != session.host
                    let hasData = !((try? session.repository.courses(includeHidden: true)) ?? []).isEmpty
                    if hostChanged && hasData {
                        confirmHostChange = true
                    } else {
                        session.saveCredentials(host: normalized, token: tokenInput)
                        if !isOnboarding { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.byuhRed)
                .disabled(!canSave)
                .confirmationDialog(
                    "Switching schools clears the local cache. Your data re-syncs from \(hostInput).",
                    isPresented: $confirmHostChange
                ) {
                    Button("Switch & Clear", role: .destructive) {
                        guard let normalized = normalizedHost else { return }
                        session.replaceCredentials(host: normalized, token: tokenInput)
                        if !isOnboarding { dismiss() }
                    }
                    Button("Cancel", role: .cancel) {}
                }

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
        .onAppear {
            if hostInput.isEmpty { hostInput = session.host }
        }
    }
}
