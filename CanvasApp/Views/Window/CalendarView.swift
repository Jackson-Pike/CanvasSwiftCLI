import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct CalendarView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @State private var viewModel = CalendarViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header bar: Mode selection + Period navigation
            HStack {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(CalendarViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        viewModel.previousPeriod()
                        Task { await viewModel.load(session: session) }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Button("Today") {
                        viewModel.selectToday()
                        Task { await viewModel.load(session: session) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        viewModel.nextPeriod()
                        Task { await viewModel.load(session: session) }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)

                    Text(periodTitle)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.inkPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            if viewModel.isLoading {
                ProgressView("Loading calendar...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error loading calendar: \(error)")
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await viewModel.load(session: session) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch viewModel.mode {
                    case .month:
                        CalendarMonthView(
                            selectedDate: viewModel.selectedDate,
                            items: viewModel.items,
                            courseColors: viewModel.courseColors,
                            onItemClick: handleItemClick
                        )
                    case .week:
                        CalendarWeekView(
                            selectedDate: viewModel.selectedDate,
                            items: viewModel.items,
                            courseColors: viewModel.courseColors,
                            onItemClick: handleItemClick
                        )
                    case .agenda:
                        CalendarAgendaView(
                            items: viewModel.items,
                            courseColors: viewModel.courseColors,
                            onItemClick: handleItemClick
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color.canvasBG)
        .task {
            await viewModel.load(session: session)
        }
    }

    private var periodTitle: String {
        let formatter = DateFormatter()
        switch viewModel.mode {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: viewModel.selectedDate)
        case .week:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: viewModel.selectedDate)
        case .agenda:
            return "Agenda"
        }
    }

    private func handleItemClick(_ item: UnifiedCalendarItem) {
        if let urlString = item.htmlUrl, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
