import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@MainActor
@Observable
final class CalendarViewModel {
    public enum Mode: String, CaseIterable, Identifiable {
        case month = "Month"
        case week = "Week"
        case agenda = "Agenda"
        public var id: String { rawValue }
    }

    public var mode: Mode = .month
    public var selectedDate: Date = Date()
    public var items: [UnifiedCalendarItem] = []
    public var courseColors: [Int: Color] = [:]
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    public init() {}

    public func load(session: AppSession) async {
        isLoading = true
        errorMessage = nil
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        let end = calendar.date(byAdding: .month, value: 2, to: selectedDate) ?? selectedDate

        do {
            try await session.syncEngine.refresh(.planner(start: start, end: end))
        } catch {
            self.errorMessage = error.localizedDescription
        }

        let repo = session.repository
        let plannerItems = (try? repo.plannerItems(start: start, end: end)) ?? []
        let calendarEvents = (try? repo.calendarEvents(start: start, end: end)) ?? []

        var unified: [UnifiedCalendarItem] = []
        for p in plannerItems {
            guard let date = p.plannableDate else { continue }
            unified.append(UnifiedCalendarItem(
                id: p.id,
                title: p.title,
                courseId: p.courseId,
                date: date,
                isEvent: false,
                locationOrSummary: nil,
                htmlUrl: p.htmlUrl,
                isCompleted: p.isCompleted,
                isMissing: p.isMissing
            ))
        }
        for c in calendarEvents {
            guard let date = c.startAt else { continue }
            unified.append(UnifiedCalendarItem(
                id: "event_\(c.id)",
                title: c.title,
                courseId: c.courseId,
                date: date,
                isEvent: true,
                locationOrSummary: c.locationName ?? c.eventDescription,
                htmlUrl: c.htmlUrl,
                isCompleted: false,
                isMissing: false
            ))
        }

        let courses = (try? repo.courses()) ?? []
        self.courseColors = Color.courseAccentMap(courseIDs: courses.map(\.id))
        self.items = unified.sorted { $0.date < $1.date }

        if !items.isEmpty {
            self.errorMessage = nil
        }
        isLoading = false
    }

    public func previousPeriod() {
        let calendar = Calendar.current
        switch mode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        case .agenda:
            selectedDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        }
    }

    public func nextPeriod() {
        let calendar = Calendar.current
        switch mode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        case .agenda:
            selectedDate = calendar.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
        }
    }

    public func selectToday() {
        selectedDate = Date()
    }
}
