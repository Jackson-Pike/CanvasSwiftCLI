import SwiftUI
import CanvasUI
import CanvasCore
import CanvasData

struct SettingsView: View {
    let isOnboarding: Bool
    @ObservedObject var vm: CoursesViewModel
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""
    @State private var tokenInput = ""
    @State private var testState: TestState = .idle
    @State private var confirmHostChange = false
    @State private var confirmReset = false
    // UserDefaults-backed, so a locally-owned instance reads/writes the same keys as any other
    // instance (e.g. the one `MainWindowBody` owns for the sidebar's below-target coloring). A
    // shared injected instance would be cleaner architecturally, but for Phase 1a the shared
    // UserDefaults keys make separate instances consistent in practice.
    @State private var courseSettings = CourseSettingsStore()
    @AppStorage("appearance") private var appearance: String = "system"

    enum TestState: Equatable {
        case idle, testing
        case success(name: String)
        case failure(message: String)
    }

    private var normalizedHost: String? { Credentials.normalizeHost(hostInput) }

    private var canTestConnection: Bool {
        normalizedHost != nil && !tokenInput.isEmpty && testState != .testing
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
                        // If the fields changed while this request was in flight, the
                        // tested pair is stale — don't let it resurrect .success/.failure
                        // for credentials that no longer match what's on screen.
                        guard normalizedHost == normalized,
                              tokenInput.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedToken
                        else { return }
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
                    // Demo mode seeds MockData into the store; those rows must be wiped before
                    // real data syncs on top, or they linger (and get merged into) the real account.
                    let leavingDemo = session.isDemo && tokenInput != "DEMO"
                    let hasData = !((try? session.repository.courses(includeHidden: true)) ?? []).isEmpty
                    if leavingDemo {
                        session.replaceCredentials(host: normalized, token: tokenInput)
                        if !isOnboarding { dismiss() }
                    } else if hostChanged && hasData {
                        confirmHostChange = true
                    } else {
                        session.saveCredentials(host: normalized, token: tokenInput)
                        if !isOnboarding { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentHypothetical)
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

                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Router is not guaranteed to be in the environment during onboarding (the
                // welcome/keychain/settings gate in MainWindowView and PopoverContent presents
                // SettingsView before the rest of the app — and its Router — is reachable), so
                // these controls, and any `@Environment(Router.self)` read, stay confined to the
                // non-onboarding path.
                if !isOnboarding {
                    CustomizationSection(vm: vm, session: session, courseSettings: courseSettings)
                    NotificationSettingsSection(session: session)
                }

                if !isOnboarding {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Local Data")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            Label("Reset Local Cache", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .confirmationDialog(
                            "Clear all cached data and re-sync from \(session.host)? Your login is kept.",
                            isPresented: $confirmReset
                        ) {
                            Button("Clear & Re-sync", role: .destructive) { session.resetCache() }
                            Button("Cancel", role: .cancel) {}
                        }
                        Text("Wipes cached courses, grades, messages, and any leftover demo data, then re-downloads everything.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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

/// The Router-dependent customization controls: default dashboard density and per-course
/// credit hours / target grades. Split out so `@Environment(Router.self)` is only resolved
/// when this view is actually built — SettingsView only instantiates it outside onboarding,
/// where Router is guaranteed to be in the environment (it's injected once at the `Window`
/// scene in `CanvasGradesApp` and inherited by every view under it, including sheets).
private struct CustomizationSection: View {
    @ObservedObject var vm: CoursesViewModel
    let session: AppSession
    let courseSettings: CourseSettingsStore
    @Environment(Router.self) private var router

    static let targetGrades = ["None", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-"]

    var body: some View {
        @Bindable var router = router
        Divider()
        VStack(alignment: .leading, spacing: 12) {
            Text("Customization")
                .font(.subheadline).foregroundStyle(.secondary)

            Picker("Default Dashboard View", selection: $router.dashboardDensity) {
                Text("Cards").tag(DashboardDensity.cards)
                Text("Ledger").tag(DashboardDensity.ledger)
            }
            .pickerStyle(.segmented)

            if !vm.courses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Courses")
                        .font(.caption).foregroundStyle(.tertiary)
                    ForEach(vm.courses, id: \.id) { course in
                        CourseSettingsRow(course: course, courseSettings: courseSettings)
                    }
                }
            }
        }
    }
}

/// One course's credit-hours stepper and target-grade picker, backed by `CourseSettingsStore`.
private struct CourseSettingsRow: View {
    let course: CachedCourse
    let courseSettings: CourseSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.courseCode).font(.subheadline)
            HStack {
                Stepper(
                    "\(courseSettings.credits(for: course.id), specifier: "%.1f") credits",
                    value: Binding(
                        get: { courseSettings.credits(for: course.id) },
                        set: { courseSettings.setCredits($0, for: course.id) }
                    ),
                    in: 0.5...6, step: 0.5
                )
                .font(.caption)

                Spacer()

                Picker("Target", selection: Binding(
                    get: { courseSettings.targetGrade(for: course.id) ?? "None" },
                    set: { courseSettings.setTargetGrade($0 == "None" ? nil : $0, for: course.id) }
                )) {
                    ForEach(CustomizationSection.targetGrades, id: \.self) { grade in
                        Text(grade).tag(grade)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }
        }
    }
}

/// Notification categories, quiet hours, and background-refresh interval (spec §6).
/// Requesting permission is lazy — deferred until the first category is switched on.
private struct NotificationSettingsSection: View {
    let session: AppSession
    @State private var store: NotificationSettingsStore

    init(session: AppSession) {
        self.session = session
        _store = State(initialValue: session.notificationSettings)
    }

    var body: some View {
        @Bindable var store = store
        Divider()
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications").font(.subheadline).foregroundStyle(.secondary)

            categoryToggle("New grades", isOn: $store.settings.newGrades)
            categoryToggle("New feedback", isOn: $store.settings.newFeedback)
            categoryToggle("New inbox messages", isOn: $store.settings.newMessages)
            categoryToggle("Assignment due soon", isOn: $store.settings.dueSoon)

            Toggle("Quiet hours", isOn: $store.settings.quietHoursEnabled).font(.caption)
            if store.settings.quietHoursEnabled {
                HStack {
                    Picker("From", selection: $store.settings.quietStartHour) { hourOptions }.frame(width: 110)
                    Picker("To", selection: $store.settings.quietEndHour) { hourOptions }.frame(width: 110)
                }
                .font(.caption)
            }

            Stepper("Background refresh: every \(store.settings.backgroundIntervalMinutes) min",
                    value: $store.settings.backgroundIntervalMinutes, in: 15...240, step: 15)
                .font(.caption)
        }
    }

    private func categoryToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                if newValue { Task { await session.scheduler.requestAuthorizationIfNeeded() } }
            }))
            .font(.caption)
    }

    private var hourOptions: some View {
        ForEach(0..<24, id: \.self) { h in
            Text(String(format: "%02d:00", h)).tag(h)
        }
    }
}
