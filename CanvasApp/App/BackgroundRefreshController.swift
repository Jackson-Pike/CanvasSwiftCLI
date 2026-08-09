import Foundation
import SwiftUI
import CanvasCore
import CanvasData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(IOKit)
import IOKit.ps
#endif
#if canImport(Network)
import Network
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor @Observable
final class BackgroundRefreshController: NSObject {
    private let session: AppSession
    private let router: Router
    private var timer: Timer?
    private var displayAsleepSince: Date?
    private let pathMonitor = NWPathMonitor()
    private var lastPathSatisfied = true

    init(session: AppSession, router: Router) {
        self.session = session; self.router = router
        super.init()
    }

    func start() {
        #if canImport(UserNotifications)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
        }
        #endif
        observeSleepWake()
        observeReachability()
        scheduleTimer()
    }

    func stop() { timer?.invalidate(); timer = nil; pathMonitor.cancel() }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(session.notificationSettings.settings.backgroundIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    /// Re-read the interval (Settings may have changed it) and reschedule.
    func rescheduleForSettingsChange() { scheduleTimer() }

    func tick() async {
        guard session.hasCredentials else { return }
        guard shouldRunBackgroundTick(power: currentPowerState(), displayAsleepSince: displayAsleepSince, now: Date())
        else { return }
        _ = await session.refresh(.all)
        _ = await session.refresh(.inbox)
        session.processUnseenChanges()
    }

    private func currentPowerState() -> PowerState {
        #if canImport(IOKit)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else { return PowerState(onBattery: false, batteryPercent: 100) }
        let state = desc[kIOPSPowerSourceStateKey] as? String
        let onBattery = state == kIOPSBatteryPowerValue
        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = max > 0 ? Int(Double(capacity) / Double(max) * 100) : 100
        return PowerState(onBattery: onBattery, batteryPercent: percent)
        #else
        return PowerState(onBattery: false, batteryPercent: 100)
        #endif
    }

    private func observeSleepWake() {
        #if canImport(AppKit)
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleepSince = Date() }
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleepSince = nil }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.tick() }   // immediate sync on wake (spec §6)
        }
        #endif
    }

    private func observeReachability() {
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let satisfied = path.status == .satisfied
                if satisfied && !self.lastPathSatisfied { await self.tick() }  // reachability returned
                self.lastPathSatisfied = satisfied
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "bg.reachability"))
        #endif
    }
}

#if canImport(UserNotifications)
extension BackgroundRefreshController: UNUserNotificationCenterDelegate {
    // Foreground presentation.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }

    // Tap → reveal (spec §6).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let json = userInfo[NotificationScheduler.revealUserInfoKey] as? String,
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NotificationRevealPayload.self, from: data) else { return }
        await MainActor.run { self.reveal(payload) }
    }

    private func reveal(_ payload: NotificationRevealPayload) {
        switch ChangeKind(rawValue: payload.kind) {
        case .newMessage:
            if let id = payload.subjectId { router.reveal(.conversation(id: id)) }
            else { router.reveal(.section(.inbox)) }
        case .newGrade, .gradeChanged, .newFeedback, .dueSoon:
            if let assignmentId = payload.subjectId {
                router.reveal(.assignment(courseId: payload.courseId, assignmentId: assignmentId))
            } else {
                router.reveal(.course(id: payload.courseId, tab: .grades))
            }
        default:
            router.reveal(.section(.dashboard))
        }
    }
}
#endif
