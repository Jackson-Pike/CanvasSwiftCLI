import Foundation

enum LegacyHiddenCourses {
    private static let key = "hiddenCourseIDs"
    static func ids() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
