import SwiftUI

struct RootView: View {
    @Environment(DemoStore.self) private var store
    @State private var tab = 0

    var body: some View {
        Group {
            if store.hasEntered {
                TabView(selection: $tab) {
                    NavigationStack { DashboardView() }
                        .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }.tag(0)
                    NavigationStack { SalesView() }
                        .tabItem { Label("Sales", systemImage: "cart.fill") }.tag(1)
                    NavigationStack { InventoryView() }
                        .tabItem { Label("Inventory", systemImage: "shippingbox.fill") }.tag(2)
                    NavigationStack { OperationsView() }
                        .tabItem { Label("Operations", systemImage: "square.stack.3d.up.fill") }.tag(3)
                    NavigationStack { MoreView() }
                        .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }.tag(4)
                }
            } else {
                WelcomeView()
            }
        }
        .alert("SmartERP Demo", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}
