import SwiftUI
import CanvasCore

public struct UnifiedCalendarItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let courseId: Int?
    public let date: Date
    public let isEvent: Bool
    public let locationOrSummary: String?
    public let htmlUrl: String?
    public let isCompleted: Bool
    public let isMissing: Bool

    public init(
        id: String,
        title: String,
        courseId: Int?,
        date: Date,
        isEvent: Bool,
        locationOrSummary: String? = nil,
        htmlUrl: String? = nil,
        isCompleted: Bool = false,
        isMissing: Bool = false
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.date = date
        self.isEvent = isEvent
        self.locationOrSummary = locationOrSummary
        self.htmlUrl = htmlUrl
        self.isCompleted = isCompleted
        self.isMissing = isMissing
    }
}

public struct CalendarEventPill: View {
    public let item: UnifiedCalendarItem
    public let courseColor: Color
    public let onItemClick: ((UnifiedCalendarItem) -> Void)?

    public init(
        item: UnifiedCalendarItem,
        courseColor: Color = .blue,
        onItemClick: ((UnifiedCalendarItem) -> Void)? = nil
    ) {
        self.item = item
        self.courseColor = courseColor
        self.onItemClick = onItemClick
    }

    public var body: some View {
        Button {
            onItemClick?(item)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(courseColor)
                    .frame(width: 6, height: 6)

                Image(systemName: item.isEvent ? "calendar" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(item.isCompleted ? .secondary : courseColor)

                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .inkPrimary)

                Spacer(minLength: 0)

                Text(item.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.inkTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.canvasPanel.opacity(0.6))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

public struct CalendarMonthView: View {
    public let selectedDate: Date
    public let items: [UnifiedCalendarItem]
    public let courseColors: [Int: Color]
    public let onItemClick: ((UnifiedCalendarItem) -> Void)?

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public init(
        selectedDate: Date,
        items: [UnifiedCalendarItem],
        courseColors: [Int: Color] = [:],
        onItemClick: ((UnifiedCalendarItem) -> Void)? = nil
    ) {
        self.selectedDate = selectedDate
        self.items = items
        self.courseColors = courseColors
        self.onItemClick = onItemClick
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        var days: [Date?] = []
        var current = firstWeek.start
        while current < monthInterval.end || days.count % 7 != 0 {
            if calendar.isDate(current, equalTo: selectedDate, toGranularity: .month) {
                days.append(current)
            } else {
                days.append(nil)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private func itemsForDay(_ date: Date) -> [UnifiedCalendarItem] {
        items.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Days of week header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<monthDays.count, id: \.self) { index in
                    if let date = monthDays[index] {
                        let dayItems = itemsForDay(date)
                        let isToday = calendar.isDateInToday(date)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.caption.weight(isToday ? .bold : .regular))
                                    .padding(4)
                                    .background(isToday ? Color.accentColor : Color.clear)
                                    .foregroundColor(isToday ? .white : .inkPrimary)
                                    .clipShape(Circle())
                                Spacer()
                            }

                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(dayItems) { item in
                                        let color = item.courseId.flatMap { courseColors[$0] } ?? .accentColor
                                        CalendarEventPill(item: item, courseColor: color, onItemClick: onItemClick)
                                    }
                                }
                            }
                        }
                        .padding(6)
                        .frame(height: 90)
                        .background(Color.canvasPanel)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.canvasHairline, lineWidth: 1)
                        )
                    } else {
                        Color.clear
                            .frame(height: 90)
                    }
                }
            }
        }
    }
}

public struct CalendarWeekView: View {
    public let selectedDate: Date
    public let items: [UnifiedCalendarItem]
    public let courseColors: [Int: Color]
    public let onItemClick: ((UnifiedCalendarItem) -> Void)?

    private let calendar = Calendar.current

    public init(
        selectedDate: Date,
        items: [UnifiedCalendarItem],
        courseColors: [Int: Color] = [:],
        onItemClick: ((UnifiedCalendarItem) -> Void)? = nil
    ) {
        self.selectedDate = selectedDate
        self.items = items
        self.courseColors = courseColors
        self.onItemClick = onItemClick
    }

    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        var days: [Date] = []
        var current = weekInterval.start
        for _ in 0..<7 {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private func itemsForDay(_ date: Date) -> [UnifiedCalendarItem] {
        items.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                let dayItems = itemsForDay(date)
                let isToday = calendar.isDateInToday(date)

                VStack(alignment: .leading, spacing: 6) {
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.inkSecondary)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.subheadline.weight(isToday ? .bold : .semibold))
                            .padding(6)
                            .background(isToday ? Color.accentColor : Color.clear)
                            .foregroundColor(isToday ? .white : .inkPrimary)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    Divider()

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(dayItems) { item in
                                let color = item.courseId.flatMap { courseColors[$0] } ?? .accentColor
                                CalendarEventPill(item: item, courseColor: color, onItemClick: onItemClick)
                            }
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.canvasPanel)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.canvasHairline, lineWidth: 1)
                )
            }
        }
    }
}

public struct CalendarAgendaView: View {
    public let items: [UnifiedCalendarItem]
    public let courseColors: [Int: Color]
    public let onItemClick: ((UnifiedCalendarItem) -> Void)?

    private let calendar = Calendar.current

    public init(
        items: [UnifiedCalendarItem],
        courseColors: [Int: Color] = [:],
        onItemClick: ((UnifiedCalendarItem) -> Void)? = nil
    ) {
        self.items = items
        self.courseColors = courseColors
        self.onItemClick = onItemClick
    }

    private var groupedItems: [(Date, [UnifiedCalendarItem])] {
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    public var body: some View {
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.largeTitle)
                    .foregroundColor(.inkTertiary)
                Text("No events or assignments scheduled")
                    .font(.callout)
                    .foregroundColor(.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedItems, id: \.0) { date, dayItems in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(date.formatted(.dateTime.month().day().weekday(.wide)))
                                    .font(.headline)
                                    .foregroundColor(.inkPrimary)

                                if calendar.isDateInToday(date) {
                                    Text("Today")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }

                            VStack(spacing: 6) {
                                ForEach(dayItems) { item in
                                    let color = item.courseId.flatMap { courseColors[$0] } ?? .accentColor
                                    Button {
                                        onItemClick?(item)
                                    } label: {
                                        HStack(spacing: 12) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(color)
                                                .frame(width: 4, height: 32)

                                            Image(systemName: item.isEvent ? "calendar" : "checklist")
                                                .foregroundColor(color)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.body.weight(.medium))
                                                    .foregroundColor(.inkPrimary)
                                                if let summary = item.locationOrSummary, !summary.isEmpty {
                                                    Text(summary)
                                                        .font(.caption)
                                                        .foregroundColor(.inkSecondary)
                                                }
                                            }

                                            Spacer()

                                            Text(item.date, style: .time)
                                                .font(.subheadline)
                                                .foregroundColor(.inkTertiary)
                                        }
                                        .padding(10)
                                        .background(Color.canvasPanel)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
