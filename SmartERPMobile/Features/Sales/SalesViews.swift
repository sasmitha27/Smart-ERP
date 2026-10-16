import SwiftUI

struct SalesView: View {
    @Environment(DemoStore.self) private var store
    @State private var creating = false

    var body: some View {
        List {
            Section { NavigationLink { CustomerListView() } label: { Label("Customers", systemImage: "person.2") } }
            Section("Sales orders") {
                if store.orders.isEmpty { Text("No orders yet. Create a customer and product, then start an order.").foregroundStyle(.secondary) }
                ForEach(store.orders) { order in
                    NavigationLink { OrderDetail(orderID: order.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(order.number).font(.headline); Spacer(); Text(Money.format(order.total)).monospacedDigit() }
                            Text(order.customerName).font(.subheadline).foregroundStyle(.secondary)
                            Text(order.status.rawValue).font(.caption).foregroundStyle(Theme.blue)
                        }.padding(.vertical, 4)
                    }
                }
            }
            Section("Invoices") {
                if store.invoices.isEmpty { Text("Create an invoice from an order.").foregroundStyle(.secondary) }
                ForEach(store.invoices) { invoice in
                    NavigationLink { InvoiceDetail(invoiceID: invoice.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(invoice.number).font(.headline); Spacer(); Text(Money.format(invoice.total)).monospacedDigit() }
                            Text(invoice.customerName).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Sales")
        .toolbar { Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New sales order") }
        .sheet(isPresented: $creating) { NavigationStack { TransactionForm(kind: .sale) } }
    }
}
