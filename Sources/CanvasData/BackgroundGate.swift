import Foundation

public struct PowerState: Sendable, Equatable {
    public let onBattery: Bool
    public let batteryPercent: Int
    public init(onBattery: Bool, batteryPercent: Int) {
        self.onBattery = onBattery; self.batteryPercent = batteryPercent
    }
}

/// Background refresh gate (spec §6): suspended on battery below 20%, and while the display
/// has been asleep more than one hour.
public func shouldRunBackgroundTick(power: PowerState, displayAsleepSince: Date?, now: Date) -> Bool {
    if power.onBattery && power.batteryPercent < 20 { return false }
    if let since = displayAsleepSince, now.timeIntervalSince(since) > 3600 { return false }
    return true
}
