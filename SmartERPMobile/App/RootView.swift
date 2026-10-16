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

struct WelcomeView: View {
    @Environment(DemoStore.self) private var store

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 86, height: 86)
                    .background(Theme.blue, in: RoundedRectangle(cornerRadius: 25))
                VStack(alignment: .leading, spacing: 8) {
                    Text("SmartERP").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Your business, in motion.").font(.title2).foregroundStyle(.secondary)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Explore a connected ERP workflow", systemImage: "checkmark.seal.fill").font(.headline)
                        Text("Create customers and products, prepare orders and purchases, receive stock, and issue demo invoices. Data stays on this device.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Label("Local demo workspace", systemImage: "iphone.gen3")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.blue)
                    }
                }
                Button { store.hasEntered = true } label: {
                    Text("Explore demo").frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                Text("Inventolo account sign-in will be available after the API contract is connected.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
    }
}

struct DashboardView: View {
    @Environment(DemoStore.self) private var store
    @State private var showingAction = false
    @State private var destination: QuickDestination?

    private var sales: Decimal { store.invoices.reduce(0) { $0 + $1.total } }
    private var receivables: Decimal { store.invoices.reduce(0) { $0 + $1.outstanding } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Good day, Alex").font(.largeTitle.bold())
                    Label("Inventolo Demo · Main branch", systemImage: "building.2")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    MetricCard(title: "Demo invoices", value: Money.format(sales), symbol: "chart.line.uptrend.xyaxis", color: Theme.blue)
                    MetricCard(title: "Outstanding", value: Money.format(receivables), symbol: "clock.arrow.circlepath", color: Theme.amber)
                }
                HStack(spacing: 12) {
                    MetricCard(title: "Pending orders", value: "\(store.orders.count)", symbol: "bag", color: Theme.teal)
                    MetricCard(title: "Low stock", value: "\(store.products.filter { $0.stock <= $0.reorderLevel }.count)", symbol: "exclamationmark.triangle", color: Theme.red)
                }
                SectionTitle("Quick actions", subtitle: "Pick up where your team left off")
                HStack(spacing: 10) {
                    quick("Customer", "person.badge.plus", .customer)
                    quick("Product", "shippingbox", .product)
                    quick("Order", "cart.badge.plus", .order)
                }
                SectionTitle("Activity", subtitle: "Saved in this demo workspace")
                Surface {
                    VStack(spacing: 14) {
                        if store.orders.isEmpty && store.purchases.isEmpty {
                            Text("Create an order or purchase to see activity here.").foregroundStyle(.secondary)
                        }
                        ForEach(store.orders.prefix(3)) { order in
                            activity(order.number, order.customerName, "cart", order.createdAt)
                        }
                        ForEach(store.purchases.prefix(2)) { purchase in
                            activity(purchase.number, purchase.supplier, "shippingbox", purchase.createdAt)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Overview")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAction = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }.accessibilityLabel("Quick actions") } }
        .confirmationDialog("Quick action", isPresented: $showingAction) {
            Button("New customer") { destination = .customer }
            Button("Add product") { destination = .product }
            Button("New sales order") { destination = .order }
            Button("New purchase") { destination = .purchase }
        }
        .sheet(item: $destination) { destination in
            NavigationStack {
                switch destination {
                case .customer: CustomerForm()
                case .product: ProductForm()
                case .order: TransactionForm(kind: .sale)
                case .purchase: TransactionForm(kind: .purchase)
                }
            }
        }
    }

    private func quick(_ title: String, _ symbol: String, _ target: QuickDestination) -> some View {
        Button { destination = target } label: {
            VStack(spacing: 9) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity).frame(height: 76)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.blue)
    }

    private func activity(_ title: String, _ subtitle: String, _ symbol: String, _ date: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 34, height: 34).background(Theme.blue.opacity(0.1), in: Circle()).foregroundStyle(Theme.blue)
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
        }
    }
}

enum QuickDestination: String, Identifiable {
    case customer, product, order, purchase
    var id: String { rawValue }
}
