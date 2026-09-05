import Foundation
import SwiftUI
import CanvasCore

enum SidebarItem: Hashable {
    case dashboard, inbox, calendar, todo
    case course(Int)

    var storageKey: String {
        switch self {
        case .dashboard: return "dashboard"
        case .inbox: return "inbox"
        case .calendar: return "calendar"
        case .todo: return "todo"
        case .course(let id): return "course:\(id)"
        }
    }

    init(storageKey: String) {
        switch storageKey {
        case "inbox": self = .inbox
        case "calendar": self = .calendar
        case "todo": self = .todo
        case let key where key.hasPrefix("course:"):
            self = Int(key.dropFirst(7)).map(SidebarItem.course) ?? .dashboard
        default: self = .dashboard
        }
    }
}

enum CourseTab: String, CaseIterable, Hashable {
    case grades, assignments, announcements, discussions, modules, files, syllabus
}

enum RevealTarget {
    case section(SidebarItem)
    case course(id: Int, tab: CourseTab)
    case assignment(courseId: Int, assignmentId: Int)
    case conversation(id: Int)
}

enum DashboardDensity: String {
    case cards, ledger
}

@MainActor @Observable
final class Router {
    var sidebar: SidebarItem {
        didSet { UserDefaults.standard.set(sidebar.storageKey, forKey: "router.sidebar") }
    }
    var courseTab: CourseTab {
        didSet { UserDefaults.standard.set(courseTab.rawValue, forKey: "router.courseTab") }
    }
    /// User-defined left-to-right order of the course tabs (drag-reorderable in the tab strip).
    /// Persisted as comma-joined raw values.
    var courseTabOrder: [CourseTab] {
        didSet {
            UserDefaults.standard.set(courseTabOrder.map(\.rawValue).joined(separator: ","),
                                      forKey: "router.courseTabOrder")
        }
    }
    var dashboardDensity: DashboardDensity {
        didSet { UserDefaults.standard.set(dashboardDensity.rawValue, forKey: "router.dashboardDensity") }
    }
    var sandboxOpen: Bool {
        didSet { UserDefaults.standard.set(sandboxOpen, forKey: "router.sandboxOpen") }
    }
    var selectedAssignmentId: Int?
    var selectedConversationId: Int?
    var quickOpenOpen: Bool = false

    init() {
        sidebar = SidebarItem(storageKey: UserDefaults.standard.string(forKey: "router.sidebar") ?? "dashboard")
        courseTab = CourseTab(rawValue: UserDefaults.standard.string(forKey: "router.courseTab") ?? "grades") ?? .grades
        // Restore the saved tab order, then append any tabs added since (e.g. after an
        // update) so every case still appears exactly once.
        let storedOrder = (UserDefaults.standard.string(forKey: "router.courseTabOrder") ?? "")
            .split(separator: ",").compactMap { CourseTab(rawValue: String($0)) }
        var order: [CourseTab] = []
        for tab in storedOrder where !order.contains(tab) { order.append(tab) }
        for tab in CourseTab.allCases where !order.contains(tab) { order.append(tab) }
        courseTabOrder = order
        let densityRaw = UserDefaults.standard.string(forKey: "router.dashboardDensity") ?? DashboardDensity.ledger.rawValue
        dashboardDensity = DashboardDensity(rawValue: densityRaw) ?? .ledger
        sandboxOpen = UserDefaults.standard.bool(forKey: "router.sandboxOpen")
    }

    func reveal(_ target: RevealTarget) {
        switch target {
        case .section(let item):
            sidebar = item
        case .course(let id, let tab):
            sidebar = .course(id); courseTab = tab; selectedAssignmentId = nil
        case .assignment(let courseId, let assignmentId):
            sidebar = .course(courseId); courseTab = .assignments; selectedAssignmentId = assignmentId
        case .conversation(let id):
            sidebar = .inbox; selectedConversationId = id
        }
    }

    func revealSearchTarget(_ target: SearchResultTarget) {
        switch target {
        case .course(let id, let tabStr):
            let tab = CourseTab(rawValue: tabStr) ?? .grades
            reveal(.course(id: id, tab: tab))
        case .assignment(let courseId, let assignmentId):
            reveal(.assignment(courseId: courseId, assignmentId: assignmentId))
        case .conversation(let id):
            reveal(.conversation(id: id))
        case .external(let url):
            if let targetURL = URL(string: url) {
                NSWorkspace.shared.open(targetURL)
            }
        }
        quickOpenOpen = false
    }
}

