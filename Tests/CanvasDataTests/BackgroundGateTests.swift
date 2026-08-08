import XCTest
@testable import CanvasData

final class BackgroundGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRunsOnACPower() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 5),
                                              displayAsleepSince: nil, now: now))
    }
    func testSkipsOnLowBattery() {
        XCTAssertFalse(shouldRunBackgroundTick(power: PowerState(onBattery: true, batteryPercent: 15),
                                               displayAsleepSince: nil, now: now))
    }
    func testRunsOnBatteryAboveThreshold() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: true, batteryPercent: 55),
                                              displayAsleepSince: nil, now: now))
    }
    func testSkipsWhenDisplayAsleepOverAnHour() {
        XCTAssertFalse(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 100),
                                               displayAsleepSince: now.addingTimeInterval(-3700), now: now))
    }
    func testRunsWhenDisplayAsleepBriefly() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 100),
                                              displayAsleepSince: now.addingTimeInterval(-600), now: now))
    }
}
