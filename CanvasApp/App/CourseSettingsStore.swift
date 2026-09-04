import Foundation

/// A user-pinned per-course shortcut (lab VM, textbook, Gradescope, Piazza, …) shown as a
/// disclosure sub-row under its course in the sidebar. `symbol` is an SF Symbol name.
struct CourseQuickLink: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var label: String
    var urlString: String
    var symbol: String
}

/// Per-course user preferences that don't come from Canvas: credit hours (for GPA weighting),
/// an aspirational target grade, and pinned quick links. UserDefaults-backed — small, keyed
/// values, no need for SwiftData.
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

    // MARK: - Quick links

    /// Bumped on every quick-link mutation. `quickLinks(for:)` reads it so `@Observable`
    /// registers a dependency and refreshes the sidebar on add/edit/remove — the links
    /// themselves live in UserDefaults (JSON), not in a tracked stored property.
    private var quickLinksRevision = 0

    func quickLinks(for courseId: Int) -> [CourseQuickLink] {
        _ = quickLinksRevision
        guard let data = defaults.data(forKey: quickLinksKey(courseId)),
              let links = try? JSONDecoder().decode([CourseQuickLink].self, from: data) else {
            return []
        }
        return links
    }

    func setQuickLinks(_ links: [CourseQuickLink], for courseId: Int) {
        if links.isEmpty {
            defaults.removeObject(forKey: quickLinksKey(courseId))
        } else if let data = try? JSONEncoder().encode(links) {
            defaults.set(data, forKey: quickLinksKey(courseId))
        }
        quickLinksRevision += 1
    }

    func addQuickLink(_ link: CourseQuickLink, for courseId: Int) {
        setQuickLinks(quickLinks(for: courseId) + [link], for: courseId)
    }

    func updateQuickLink(_ link: CourseQuickLink, for courseId: Int) {
        var links = quickLinks(for: courseId)
        guard let index = links.firstIndex(where: { $0.id == link.id }) else { return }
        links[index] = link
        setQuickLinks(links, for: courseId)
    }

    func removeQuickLink(_ id: UUID, for courseId: Int) {
        setQuickLinks(quickLinks(for: courseId).filter { $0.id != id }, for: courseId)
    }

    private func creditsKey(_ courseId: Int) -> String { "course.credits.\(courseId)" }
    private func targetKey(_ courseId: Int) -> String { "course.target.\(courseId)" }
    private func quickLinksKey(_ courseId: Int) -> String { "course.quicklinks.\(courseId)" }
}
