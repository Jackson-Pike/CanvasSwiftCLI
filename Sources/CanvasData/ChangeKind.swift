import Foundation

public enum ChangeKind: String, Codable, Sendable, CaseIterable {
    case newGrade, gradeChanged, newFeedback, newAnnouncement, newMessage, dueSoon
}
