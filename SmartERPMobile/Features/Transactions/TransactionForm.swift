import SwiftUI

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
