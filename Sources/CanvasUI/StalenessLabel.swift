import SwiftUI

/// Small caption showing how stale the cached data is, per spec §5.8.
public struct StalenessLabel: View {
    private let lastSyncedAt: Date?

    public init(lastSyncedAt: Date?) {
        self.lastSyncedAt = lastSyncedAt
    }

    public var body: some View {
        Group {
            if let lastSyncedAt {
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: lastSyncedAt, relativeTo: .now))")
            } else {
                Text("Not synced yet")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        StalenessLabel(lastSyncedAt: Date().addingTimeInterval(-300))
        StalenessLabel(lastSyncedAt: Date().addingTimeInterval(-3600 * 26))
        StalenessLabel(lastSyncedAt: nil)
    }
    .padding()
}
