import Foundation

/// Per-course user preferences that don't come from Canvas: credit hours (for GPA weighting)
/// and an aspirational target grade. UserDefaults-backed — small, keyed scalars, no need for
/// SwiftData.
@MainActor @Observable
final class CourseSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Defaults to 3.0 credits. A stored `0` (e.g. from a stale/never-set key) is treated as
    /// unset rather than a real zero-credit course, since 0 credits would silently zero out
    /// that course's contribution to GPA.
    func credits(for courseId: Int) -> Double {
        let stored = defaults.double(forKey: creditsKey(courseId))
        return stored == 0 ? 3.0 : stored
    }

    func setCredits(_ credits: Double, for courseId: Int) {
        defaults.set(credits, forKey: creditsKey(courseId))
    }

    func targetGrade(for courseId: Int) -> String? {
        defaults.string(forKey: targetKey(courseId))
    }

    func setTargetGrade(_ grade: String?, for courseId: Int) {
        if let grade {
            defaults.set(grade, forKey: targetKey(courseId))
        } else {
            defaults.removeObject(forKey: targetKey(courseId))
        }
    }

    private func creditsKey(_ courseId: Int) -> String { "course.credits.\(courseId)" }
    private func targetKey(_ courseId: Int) -> String { "course.target.\(courseId)" }
}
