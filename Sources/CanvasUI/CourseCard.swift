import SwiftUI

/// Value-driven replacement for the old `CourseCardView`. The caller computes
/// `letter` (via `letterGrade(for:scale:)`) rather than passing a `Course`.
public struct CourseCard: View {
    private let name: String
    private let courseCode: String
    private let score: Double?
    private let letter: String?

    public init(name: String, courseCode: String, score: Double?, letter: String?) {
        self.name = name
        self.courseCode = courseCode
        self.score = score
        self.letter = letter
    }

    private var displayLetter: String { letter ?? "—" }

    private var gradeColor: Color {
        guard let letter else { return Color.secondaryLabel }
        return Color.letterGradeColor(letter)
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(courseCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let score {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                gradeColor.opacity(0.15)
                Text(displayLetter)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(gradeColor)
            }
            .frame(width: 90)
        }
        .background(Color.canvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.canvasHairline, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        CourseCard(name: "Intro to Swift Programming", courseCode: "CS 101", score: 92.5, letter: "A")
        CourseCard(name: "Data Structures", courseCode: "CS 210", score: 81.2, letter: "B-")
        CourseCard(name: "Ungraded Seminar", courseCode: "REL 250", score: nil, letter: nil)
    }
    .padding()
}
