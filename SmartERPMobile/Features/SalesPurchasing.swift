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

enum TransactionKind { case sale, purchase }

struct TransactionForm: View {
    let kind: TransactionKind
    @Environment(DemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var customerID: UUID?
    @State private var supplier = ""
    @State private var quantities: [UUID: Int] = [:]
    @State private var scanning = false
    @State private var error = ""

    private var lines: [LineItem] {
        store.products.compactMap { product in
            let quantity = quantities[product.id, default: 0]
            guard quantity > 0 else { return nil }
            return LineItem(productID: product.id, name: product.name, quantity: quantity, unitPrice: kind == .sale ? product.price : product.cost)
        }
    }
    private var total: Decimal { lines.reduce(0) { $0 + $1.total } }

    var body: some View {
        Form {
            if kind == .sale {
                Section("Customer") {
                    Picker("Select customer", selection: $customerID) {
                        Text("Choose a customer").tag(nil as UUID?)
                        ForEach(store.customers) { Text($0.name).tag($0.id as UUID?) }
                    }
                    if store.customers.isEmpty { Text("Add a customer from Sales → Customers first.").foregroundStyle(.secondary) }
                }
            } else {
                Section("Supplier") { TextField("Supplier name", text: $supplier) }
            }
            Section("Products") {
                Button { scanning = true } label: { Label("Scan or enter barcode", systemImage: "barcode.viewfinder") }
                ForEach(store.products) { product in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.name).font(.subheadline.weight(.semibold))
                            Text(Money.format(kind == .sale ? product.price : product.cost)).font(.caption).foregroundStyle(.secondary)
                            if kind == .sale { Text("\(product.stock) available in demo").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Stepper("\(quantities[product.id, default: 0])", value: Binding(get: { quantities[product.id, default: 0] }, set: { quantities[product.id] = $0 }), in: 0...999).labelsHidden()
                        Text("\(quantities[product.id, default: 0])").monospacedDigit().frame(width: 28)
                    }
                }
                if store.products.isEmpty { Text("Add a product from Inventory first.").foregroundStyle(.secondary) }
            }
            Section("Review") {
                ForEach(lines) { line in LabeledContent("\(line.name) × \(line.quantity)", value: Money.format(line.total)) }
                LabeledContent("Total", value: Money.format(total)).fontWeight(.bold)
                Text("Saved locally as a demo draft. No server posting or inventory movement occurs.").font(.caption).foregroundStyle(.secondary)
            }
            if !error.isEmpty { Section { Text(error).foregroundStyle(Theme.red) } }
        }
        .navigationTitle(kind == .sale ? "New sales order" : "New purchase")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save draft") { submit() } }
        }
        .sheet(isPresented: $scanning) {
            BarcodeSheet { code in
                if let product = store.product(for: code) { quantities[product.id, default: 0] += 1 }
                else { error = "No product matches barcode \(code)." }
                scanning = false
            }
        }
    }

    private func submit() {
        guard !lines.isEmpty else { error = "Add at least one product."; return }
        if kind == .sale {
            guard let customer = store.customers.first(where: { $0.id == customerID }) else { error = "Select a customer."; return }
            guard lines.allSatisfy({ line in store.products.first(where: { $0.id == line.productID }).map { line.quantity <= $0.stock } ?? false }) else { error = "One or more quantities exceed demo stock."; return }
            store.addOrder(customer: customer, lines: lines)
        } else {
            guard !supplier.trimmingCharacters(in: .whitespaces).isEmpty else { error = "Enter a supplier."; return }
            store.addPurchase(supplier: supplier, lines: lines)
        }
        dismiss()
    }
}

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

struct PurchaseListView: View {
    @Environment(DemoStore.self) private var store
    @State private var creating = false
    var body: some View {
        List {
            if store.purchases.isEmpty { Text("No purchases yet. Create a purchase draft to begin receiving.").foregroundStyle(.secondary) }
            ForEach(store.purchases) { purchase in
                NavigationLink { PurchaseDetail(purchaseID: purchase.id) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(purchase.number).font(.headline); Spacer(); Text(Money.format(purchase.total)).monospacedDigit() }
                        Text(purchase.supplier).foregroundStyle(.secondary)
                        Text(purchase.complete ? "Received in demo" : "Awaiting receipt").font(.caption).foregroundStyle(purchase.complete ? Theme.green : Theme.amber)
                    }.padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Purchasing")
        .toolbar { Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New purchase") }
        .sheet(isPresented: $creating) { NavigationStack { TransactionForm(kind: .purchase) } }
    }
}

struct PurchaseDetail: View {
    @Environment(DemoStore.self) private var store
    let purchaseID: UUID
    @State private var receiving = false

    var body: some View {
        Group {
            if let purchase = store.purchases.first(where: { $0.id == purchaseID }) {
                List {
                    Section { Text(purchase.number).font(.title2.bold()); Text(purchase.supplier) }
                    Section("Items") {
                        ForEach(purchase.lines) { line in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(line.name).font(.headline)
                                Text("Received \(purchase.received[line.productID, default: 0]) of \(line.quantity)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section { LabeledContent("Total", value: Money.format(purchase.total)) }
                    if !purchase.complete { Section { Button("Receive goods in demo") { receiving = true } } }
                }
            }
        }
        .navigationTitle("Purchase")
        .sheet(isPresented: $receiving) { NavigationStack { ReceivingForm(purchaseID: purchaseID) } }
    }
}

struct ReceivingForm: View {
    @Environment(DemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let purchaseID: UUID
    @State private var quantities: [UUID: Int] = [:]
    @State private var showingConfirmation = false

    var body: some View {
        Form {
            if let purchase = store.purchases.first(where: { $0.id == purchaseID }) {
                Section("Received quantities") {
                    ForEach(purchase.lines) { line in
                        let remaining = max(0, line.quantity - purchase.received[line.productID, default: 0])
                        Stepper("\(line.name): \(quantities[line.productID, default: 0]) / \(remaining)", value: Binding(get: { quantities[line.productID, default: 0] }, set: { quantities[line.productID] = $0 }), in: 0...remaining)
                    }
                }
                Section { Text("This updates local demo stock only. Backend goods receipt posting is not connected.").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Receive goods")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Review") { showingConfirmation = true }.disabled(!quantities.values.contains(where: { $0 > 0 })) }
        }
        .confirmationDialog("Save this demo receipt?", isPresented: $showingConfirmation) {
            Button("Save receipt") { store.receive(purchaseID: purchaseID, quantities: quantities); dismiss() }
        } message: { Text("Partial quantities remain available for a later receipt. Duplicate quantities are capped.") }
    }
}
