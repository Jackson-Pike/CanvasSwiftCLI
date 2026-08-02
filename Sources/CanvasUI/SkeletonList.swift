import SwiftUI

/// Cold-cache loading placeholder: a stack of redacted bars, per spec §5.8.
public struct SkeletonList: View {
    private let rows: Int

    public init(rows: Int = 6) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 60)
            }
        }
        .padding()
        .redacted(reason: .placeholder)
    }
}

#Preview {
    SkeletonList(rows: 4)
}
