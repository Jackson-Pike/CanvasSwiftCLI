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
            Text("Enter your Canvas API token")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            SecureField("Canvas API Token", text: $tokenInput)
                .textFieldStyle(.roundedBorder)
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
