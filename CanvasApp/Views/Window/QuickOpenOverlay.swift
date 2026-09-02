import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct QuickOpenOverlay: View {
    @StateObject private var vm = QuickOpenViewModel()
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerSearchField
            Divider()
            resultsList
        }
        .frame(width: 540, height: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .onAppear {
            isFieldFocused = true
            vm.performSearch(session: session)
        }
        .onChange(of: vm.query) { _, _ in
            vm.performSearch(session: session)
        }
        .onKeyPress(.upArrow) {
            vm.moveSelection(up: true)
            return .handled
        }
        .onKeyPress(.downArrow) {
            vm.moveSelection(up: false)
            return .handled
        }
        .onKeyPress(.escape) {
            router.quickOpenOpen = false
            return .handled
        }
    }

    private var headerSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.inkSecondary)

            TextField("Search courses, assignments, files, topics…", text: $vm.query)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .focused($isFieldFocused)
                .onSubmit {
                    vm.selectCurrent(router: router)
                }

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)
            }

            Text("ESC")
                .font(.mono(10, weight: .semibold))
                .foregroundStyle(Color.inkTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.inkPrimary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var resultsList: some View {
        Group {
            if vm.results.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.inkTertiary)
                    Text(vm.query.isEmpty ? "Type to search Canvas items…" : "No matching items found")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(vm.results.enumerated()), id: \.element.id) { index, item in
                                SearchResultRow(item: item, isSelected: vm.selectedIndex == index) {
                                    vm.selectedIndex = index
                                    vm.selectCurrent(router: router)
                                }
                                .id(index)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: vm.selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
