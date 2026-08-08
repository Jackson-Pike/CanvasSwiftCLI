import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
public final class NotificationScheduler {
    public static let revealUserInfoKey = "reveal"
    private var didRequestAuthorization = false

    public init() {}

    /// Lazy permission (spec §6): requested the first time any category is enabled, never at launch.
    @discardableResult
    public func requestAuthorizationIfNeeded() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            didRequestAuthorization = true
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return settings.authorizationStatus == .authorized
        #else
        return false
        #endif
    }

    public func post(_ specs: [NotificationRequestSpec]) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        for spec in specs {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            if let data = try? JSONEncoder().encode(spec.payload),
               let json = String(data: data, encoding: .utf8) {
                content.userInfo = [Self.revealUserInfoKey: json]
            }
            center.add(UNNotificationRequest(identifier: spec.identifier, content: content, trigger: nil))
        }
        #endif
    }

    /// Menu-bar/app badge count of unseen changes (spec §6).
    public func setBadge(_ count: Int) {
        #if canImport(AppKit)
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
        #endif
    }
}
