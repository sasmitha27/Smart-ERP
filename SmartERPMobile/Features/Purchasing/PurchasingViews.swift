import SwiftUI

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
