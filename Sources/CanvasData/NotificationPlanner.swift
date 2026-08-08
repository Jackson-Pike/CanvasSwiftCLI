import Foundation
import CanvasCore

public struct NotificationSettings: Sendable, Equatable {
    public var newGrades: Bool
    public var newFeedback: Bool
    public var newMessages: Bool
    public var dueSoon: Bool
    public var quietHoursEnabled: Bool
    public var quietStartHour: Int   // 0–23
    public var quietEndHour: Int     // 0–23
    public var backgroundIntervalMinutes: Int   // clamped 15…240 by the store

    public init(newGrades: Bool, newFeedback: Bool, newMessages: Bool, dueSoon: Bool,
                quietHoursEnabled: Bool, quietStartHour: Int, quietEndHour: Int, backgroundIntervalMinutes: Int) {
        self.newGrades = newGrades; self.newFeedback = newFeedback; self.newMessages = newMessages
        self.dueSoon = dueSoon; self.quietHoursEnabled = quietHoursEnabled
        self.quietStartHour = quietStartHour; self.quietEndHour = quietEndHour
        self.backgroundIntervalMinutes = backgroundIntervalMinutes
    }

    public static let defaults = NotificationSettings(
        newGrades: true, newFeedback: true, newMessages: false, dueSoon: false,
        quietHoursEnabled: false, quietStartHour: 22, quietEndHour: 7, backgroundIntervalMinutes: 30)

    public func enabled(for kind: ChangeKind) -> Bool {
        switch kind {
        case .newGrade, .gradeChanged: return newGrades
        case .newFeedback:             return newFeedback
        case .newMessage:              return newMessages
        case .dueSoon:                 return dueSoon
        case .newAnnouncement:         return false   // no announcement category in Phase 2 spec §6
        }
    }
}

/// Enough to route a notification tap back to a `RevealTarget` (spec §6). Encoded into the
/// UNNotificationRequest userInfo by the scheduler.
public struct NotificationRevealPayload: Sendable, Equatable, Codable {
    public let kind: String
    public let courseId: Int
    public let subjectId: Int?
    public init(kind: String, courseId: Int, subjectId: Int?) {
        self.kind = kind; self.courseId = courseId; self.subjectId = subjectId
    }
}

public struct NotificationRequestSpec: Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let payload: NotificationRevealPayload
}

public enum NotificationPlanner {
    public static func isInQuietHours(_ date: Date, settings: NotificationSettings,
                                      calendar: Calendar = .current) -> Bool {
        guard settings.quietHoursEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        let start = settings.quietStartHour, end = settings.quietEndHour
        if start == end { return false }
        if start < end { return hour >= start && hour < end }         // same-day window
        return hour >= start || hour < end                            // wrap-around (e.g. 22→7)
    }

    private static func label(_ kind: ChangeKind, count: Int) -> String {
        switch kind {
        case .newGrade:        return count == 1 ? "new grade" : "new grades"
        case .gradeChanged:    return count == 1 ? "grade change" : "grade changes"
        case .newFeedback:     return count == 1 ? "new comment" : "new comments"
        case .newMessage:      return count == 1 ? "new message" : "new messages"
        case .dueSoon:         return count == 1 ? "assignment due soon" : "assignments due soon"
        case .newAnnouncement: return count == 1 ? "announcement" : "announcements"
        }
    }

    /// Groups enabled changes by (kind, courseId). > 3 in a group → one summary spec; else one each.
    /// Returns `post` (fire now) and `suppressed` (in quiet hours — caller still keeps them in the feed).
    public static func plan(changes: [ChangeRecord], settings: NotificationSettings, now: Date,
                            calendar: Calendar = .current)
        -> (post: [NotificationRequestSpec], suppressed: [NotificationRequestSpec]) {
        let quiet = isInQuietHours(now, settings: settings, calendar: calendar)
        var specs: [NotificationRequestSpec] = []
        let enabled = changes.filter { $0.changeKind.map(settings.enabled(for:)) ?? false }

        // Preserve grouping order by first appearance.
        var order: [String] = []
        var groups: [String: [ChangeRecord]] = [:]
        for c in enabled {
            let key = "\(c.kind)#\(c.courseId)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(c)
        }

        for key in order {
            let group = groups[key]!
            guard let kind = group.first?.changeKind else { continue }
            if group.count > 3 {
                let spec = NotificationRequestSpec(
                    identifier: "summary-\(key)-\(Int(now.timeIntervalSince1970))",
                    title: group.first?.title ?? "Canvas",
                    body: "\(group.count) \(label(kind, count: group.count))",
                    payload: NotificationRevealPayload(kind: kind.rawValue, courseId: group.first!.courseId, subjectId: nil))
                specs.append(spec)
            } else {
                for c in group {
                    let spec = NotificationRequestSpec(
                        identifier: "change-\(c.id.uuidString)",
                        title: c.title,
                        body: [label(kind, count: 1).capitalized, c.detail].compactMap { $0 }.joined(separator: " · "),
                        payload: NotificationRevealPayload(kind: kind.rawValue, courseId: c.courseId, subjectId: c.subjectId))
                    specs.append(spec)
                }
            }
        }
        return quiet ? (post: [], suppressed: specs) : (post: specs, suppressed: [])
    }
}
