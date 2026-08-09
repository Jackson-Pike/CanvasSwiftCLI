import Foundation

enum LegacyHiddenCourses {
    private static let key = "hiddenCourseIDs"
    static func ids(userDefaults: UserDefaults = .standard) -> Set<Int> {
        Set(userDefaults.array(forKey: key) as? [Int] ?? [])
    }
    static func clear(userDefaults: UserDefaults = .standard) { userDefaults.removeObject(forKey: key) }
}
