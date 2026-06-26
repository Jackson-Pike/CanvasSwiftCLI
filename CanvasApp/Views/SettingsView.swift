import SwiftUI

struct SettingsView: View {
    let isOnboarding: Bool
    @EnvironmentObject var appState: AppState
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
        }
        .padding(24)
        .frame(width: 340)
    }
}
