import SwiftUI
import CanvasUI

struct KeychainWarningView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)

                Text("One quick thing")
                    .font(.title2.bold())

                Text("macOS will ask for your Keychain password to securely store your Canvas API token. This only happens once — your token stays on this Mac and is never sent anywhere.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Text("If macOS asks 'Allow CanvasApp to use your confidential information,' click Always Allow.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)

                Button {
                    appState.acknowledgeKeychain()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.byuhRed)
                .controlSize(.large)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 28)
        }
    }
}
