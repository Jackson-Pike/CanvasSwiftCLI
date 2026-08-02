import Foundation
import SwiftUI

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

@MainActor @Observable
final class Router {
    var sidebar: SidebarItem {
        didSet { UserDefaults.standard.set(sidebar.storageKey, forKey: "router.sidebar") }
    }
    var courseTab: CourseTab {
        didSet { UserDefaults.standard.set(courseTab.rawValue, forKey: "router.courseTab") }
    }
    var selectedAssignmentId: Int?
    var selectedConversationId: Int?

    init() {
        sidebar = SidebarItem(storageKey: UserDefaults.standard.string(forKey: "router.sidebar") ?? "dashboard")
        courseTab = CourseTab(rawValue: UserDefaults.standard.string(forKey: "router.courseTab") ?? "grades") ?? .grades
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
}
