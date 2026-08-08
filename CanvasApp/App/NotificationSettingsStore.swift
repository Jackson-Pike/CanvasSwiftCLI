import Foundation
import CanvasData

@MainActor @Observable
final class NotificationSettingsStore {
    var settings: NotificationSettings { didSet { persist() } }

    private static let key = "notificationSettings.v1"

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            settings = decoded.toSettings()
        } else {
            settings = .defaults
        }
    }

    private func persist() {
        // Clamp the interval to the spec's 15 min–4 h band before saving.
        settings.backgroundIntervalMinutes = min(max(settings.backgroundIntervalMinutes, 15), 240)
        if let data = try? JSONEncoder().encode(Stored(settings)) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    var anyCategoryEnabled: Bool {
        settings.newGrades || settings.newFeedback || settings.newMessages || settings.dueSoon
    }

    /// Codable mirror (NotificationSettings itself is not Codable to keep CanvasData framework-free).
    private struct Stored: Codable {
        var newGrades, newFeedback, newMessages, dueSoon, quietHoursEnabled: Bool
        var quietStartHour, quietEndHour, backgroundIntervalMinutes: Int
        init(_ s: NotificationSettings) {
            newGrades = s.newGrades; newFeedback = s.newFeedback; newMessages = s.newMessages; dueSoon = s.dueSoon
            quietHoursEnabled = s.quietHoursEnabled; quietStartHour = s.quietStartHour
            quietEndHour = s.quietEndHour; backgroundIntervalMinutes = s.backgroundIntervalMinutes
        }
        func toSettings() -> NotificationSettings {
            NotificationSettings(newGrades: newGrades, newFeedback: newFeedback, newMessages: newMessages,
                                 dueSoon: dueSoon, quietHoursEnabled: quietHoursEnabled,
                                 quietStartHour: quietStartHour, quietEndHour: quietEndHour,
                                 backgroundIntervalMinutes: backgroundIntervalMinutes)
        }
    }
}
