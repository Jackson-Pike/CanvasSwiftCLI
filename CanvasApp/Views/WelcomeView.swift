import SwiftUI
import CanvasUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Hero
            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.byuhRed)
                Text("Canvas Grades")
                    .font(.title2.bold())
                Text("Quick grade access from your menu bar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal)

            Spacer()

            // Disclosures
            VStack(alignment: .leading, spacing: 16) {
                DisclosureRow(
                    icon: "lock.fill",
                    color: .green,
                    title: "Your data stays on this Mac",
                    message: "Your API token is stored in the system Keychain. Grade data is fetched directly from Canvas and never sent anywhere else."
                )
                DisclosureRow(
                    icon: "exclamationmark.shield.fill",
                    color: Color.byuhGold,
                    title: "Unofficial app",
                    message: "Canvas Grades is an independent tool and is not affiliated with, endorsed by, or officially connected to Instructure, Inc. or the Canvas LMS."
                )
                DisclosureRow(
                    icon: "person.fill.xmark",
                    color: .secondary,
                    title: "No account created",
                    message: "This app uses your existing Canvas API token to read your grades. Nothing is stored on any server."
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // CTA
            Button {
                appState.completeIntro()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.byuhRed)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}

private struct DisclosureRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
