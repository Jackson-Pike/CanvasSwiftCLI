import SwiftUI

/// The repeated letter-grade capsule (`A`, `B+`, …) shared by `GradeDashboard` and
/// `GroupBreakdownRow`.
public struct LetterBadge: View {
    private let letter: String

    public init(letter: String) {
        self.letter = letter
    }

    public var body: some View {
        Text(letter)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.letterGradeColor(letter), in: Capsule())
    }
}

#Preview {
    HStack(spacing: 8) {
        LetterBadge(letter: "A")
        LetterBadge(letter: "B-")
        LetterBadge(letter: "C+")
        LetterBadge(letter: "F")
    }
    .padding()
}
