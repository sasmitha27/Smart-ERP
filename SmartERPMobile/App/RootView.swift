import SwiftUI

struct RootView: View {
    @Environment(DemoStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var tab = 0
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    private var usesSidebarNavigation: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    private let sections: [(title: String, symbol: String)] = [
        ("Home", "square.grid.2x2.fill"),
        ("Sales", "cart.fill"),
        ("Inventory", "shippingbox.fill"),
        ("Operations", "square.stack.3d.up.fill"),
        ("More", "ellipsis.circle.fill")
    ]

    var body: some View {
        Group {
            if store.hasEntered {
                if usesSidebarNavigation {
                    NavigationSplitView(columnVisibility: $splitViewVisibility) {
                        List {
                            ForEach(sections.indices, id: \.self) { index in
                                Button { tab = index } label: {
                                    Label(sections[index].title, systemImage: sections[index].symbol)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(tab == index ? Theme.blue : .primary)
                                .listRowBackground(tab == index ? Theme.blue.opacity(0.12) : Color.clear)
                                .accessibilityAddTraits(tab == index ? .isSelected : [])
                            }
                        }
                        .navigationTitle("SmartERP")
                        .listStyle(.sidebar)
                    } detail: {
                        NavigationStack { section(tab) }
                            .id(tab)
                    }
                    .navigationSplitViewStyle(.balanced)
                } else {
                    TabView(selection: $tab) {
                        ForEach(sections.indices, id: \.self) { index in
                            NavigationStack { section(index) }
                                .tabItem { Label(sections[index].title, systemImage: sections[index].symbol) }
                                .tag(index)
                        }
                    }
                }
            } else {
                WelcomeView()
            }
        }
        .alert("SmartERP Demo", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    @ViewBuilder
    private func section(_ index: Int) -> some View {
        switch index {
        case 0: DashboardView()
        case 1: SalesView()
        case 2: InventoryView()
        case 3: OperationsView()
        default: MoreView()
        }
    }
}
