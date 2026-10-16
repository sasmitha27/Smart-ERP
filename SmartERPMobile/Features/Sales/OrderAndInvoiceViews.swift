import SwiftUI

struct OrderDetail: View {
    @Environment(DemoStore.self) private var store
    let orderID: UUID

    var body: some View {
        Group {
            if let order = store.orders.first(where: { $0.id == orderID }) {
                List {
                    Section { Text(order.number).font(.title2.bold()); Text(order.customerName); Text(order.createdAt, style: .date).foregroundStyle(.secondary) }
                    Section("Items") { ForEach(order.lines) { line in LabeledContent("\(line.name) × \(line.quantity)", value: Money.format(line.total)) } }
                    Section { LabeledContent("Total", value: Money.format(order.total)).fontWeight(.bold) }
                    Section {
                        if store.invoices.contains(where: { $0.orderID == orderID }) { Label("Demo invoice created", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green) }
                        else { Button("Create demo invoice") { store.createInvoice(orderID: orderID) } }
                        Text("Invoice numbers and posting require the Inventolo backend. This invoice remains local demo data.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Order details")
    }
}

struct InvoiceDetail: View {
    @Environment(DemoStore.self) private var store
    let invoiceID: UUID
    @State private var payment = ""
    @State private var showingPayment = false

    var body: some View {
        Group {
            if let invoice = store.invoices.first(where: { $0.id == invoiceID }) {
                List {
                    Section { Text(invoice.number).font(.title2.bold()); Text(invoice.customerName); Text(invoice.createdAt, style: .date).foregroundStyle(.secondary) }
                    Section("Items") { ForEach(invoice.lines) { line in LabeledContent("\(line.name) × \(line.quantity)", value: Money.format(line.total)) } }
                    Section("Summary") {
                        LabeledContent("Total", value: Money.format(invoice.total))
                        LabeledContent("Demo payments", value: Money.format(invoice.paid))
                        LabeledContent("Outstanding", value: Money.format(invoice.outstanding)).fontWeight(.bold)
                    }
                    Section { Button("Record demo payment") { showingPayment = true }.disabled(invoice.outstanding <= 0) }
                }
            }
        }
        .navigationTitle("Invoice")
        .alert("Record demo payment", isPresented: $showingPayment) {
            TextField("Amount in LKR", text: $payment).keyboardType(.decimalPad)
            Button("Save") { if let amount = Decimal(string: payment) { store.recordPayment(invoiceID: invoiceID, amount: amount) }; payment = "" }
            Button("Cancel", role: .cancel) { payment = "" }
        } message: { Text("Local demo only. This does not collect or post a payment.") }
    }
}
