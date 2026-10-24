import Foundation
import Observation
import SwiftData

@Model
final class DatabaseSnapshotRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String = "primary", payload: Data, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@MainActor @Observable
final class DemoStore {
    var hasEntered = false
    var customers: [Customer] = []
    var products: [Product] = []
    var orders: [SalesOrder] = []
    var purchases: [PurchaseOrder] = []
    var invoices: [Invoice] = []
    var visits: [Visit] = []
    var activeWorkSession = false
    var lastSaved: Date?
    var message: String?

    private struct Snapshot: Codable {
        var customers: [Customer]
        var products: [Product]
        var orders: [SalesOrder]
        var purchases: [PurchaseOrder]
        var invoices: [Invoice]
        var visits: [Visit]
    }

    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var modelContext: ModelContext?

    private let legacyFileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SmartERP/demo-data.json")
    }()

    init() {
        do {
            let container = try ModelContainer(for: DatabaseSnapshotRecord.self)
            modelContainer = container
            modelContext = ModelContext(container)
        } catch {
            message = "Could not open the local database: \(error.localizedDescription)"
        }

        if loadFromDatabase() {
            return
        }

        // Migrate data written by earlier versions of the app into SwiftData.
        if let data = try? Data(contentsOf: legacyFileURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            apply(snapshot)
            save()
            try? FileManager.default.removeItem(at: legacyFileURL)
        } else {
            seed()
        }
    }

    private func loadFromDatabase() -> Bool {
        guard let modelContext else { return false }

        do {
            var descriptor = FetchDescriptor<DatabaseSnapshotRecord>()
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else { return false }
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: record.payload)
            apply(snapshot)
            lastSaved = record.updatedAt
            return true
        } catch {
            message = "Could not read the local database: \(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ snapshot: Snapshot) {
        customers = snapshot.customers
        products = snapshot.products
        orders = snapshot.orders
        purchases = snapshot.purchases
        invoices = snapshot.invoices
        visits = snapshot.visits
    }

    private func seed() {
        let c1 = Customer(name: "ABC Distributors", phone: "+94 11 234 5678", email: "accounts@abc.example", address: "Colombo 03")
        let c2 = Customer(name: "Sunrise Retail", phone: "+94 77 555 0184", email: "hello@sunrise.example", address: "Kandy")
        customers = [c1, c2]
        products = [
            Product(name: "Arabica Coffee Beans", sku: "COF-001", barcode: "4791234567890", category: "Beverages", price: 3200, cost: 2100, stock: 24),
            Product(name: "Ceramic Mug", sku: "MUG-004", barcode: "4791234567891", category: "Home", price: 1850, cost: 990, stock: 3),
            Product(name: "Green Tea Box", sku: "TEA-012", barcode: "4791234567892", category: "Beverages", price: 1450, cost: 820, stock: 18)
        ]
        visits = [Visit(name: "ABC Distributors", address: "Colombo 03", latitude: 6.9006, longitude: 79.8533, scheduledAt: .now.addingTimeInterval(3600 * 3))]
        save()
    }

    func save() {
        guard let modelContext else {
            if message == nil {
                message = "The local database is unavailable. Changes will not persist."
            }
            return
        }

        let snapshot = Snapshot(customers: customers, products: products, orders: orders, purchases: purchases, invoices: invoices, visits: visits)
        do {
            let data = try JSONEncoder().encode(snapshot)
            var descriptor = FetchDescriptor<DatabaseSnapshotRecord>()
            descriptor.fetchLimit = 1
            let savedAt = Date.now

            if let record = try modelContext.fetch(descriptor).first {
                record.payload = data
                record.updatedAt = savedAt
            } else {
                modelContext.insert(DatabaseSnapshotRecord(payload: data, updatedAt: savedAt))
            }

            try modelContext.save()
            lastSaved = savedAt
        } catch {
            modelContext.rollback()
            message = "Could not save to the local database: \(error.localizedDescription)"
        }
    }

    func addCustomer(_ customer: Customer) { customers.insert(customer, at: 0); save() }
    func addProduct(_ product: Product) { products.insert(product, at: 0); save() }

    func addOrder(customer: Customer, lines: [LineItem]) {
        guard !lines.isEmpty else { return }
        let number = "DEMO-SO-\(String(format: "%04d", orders.count + 1))"
        orders.insert(SalesOrder(number: number, customerID: customer.id, customerName: customer.name, lines: lines), at: 0)
        save()
    }

    func addPurchase(supplier: String, lines: [LineItem]) {
        guard !supplier.trimmingCharacters(in: .whitespaces).isEmpty, !lines.isEmpty else { return }
        let number = "DEMO-PO-\(String(format: "%04d", purchases.count + 1))"
        purchases.insert(PurchaseOrder(number: number, supplier: supplier, lines: lines), at: 0)
        save()
    }

    func receive(purchaseID: UUID, quantities: [UUID: Int]) {
        guard let index = purchases.firstIndex(where: { $0.id == purchaseID }) else { return }
        for line in purchases[index].lines {
            let remaining = max(0, line.quantity - purchases[index].received[line.productID, default: 0])
            let amount = min(remaining, max(0, quantities[line.productID, default: 0]))
            guard amount > 0 else { continue }
            purchases[index].received[line.productID, default: 0] += amount
            if let productIndex = products.firstIndex(where: { $0.id == line.productID }) {
                products[productIndex].stock += amount
            }
        }
        save()
    }

    func createInvoice(orderID: UUID) {
        guard let order = orders.first(where: { $0.id == orderID }), !invoices.contains(where: { $0.orderID == orderID }) else { return }
        let number = "DEMO-INV-\(String(format: "%04d", invoices.count + 1))"
        invoices.insert(Invoice(number: number, orderID: orderID, customerName: order.customerName, lines: order.lines), at: 0)
        save()
    }

    func recordPayment(invoiceID: UUID, amount: Decimal) {
        guard let index = invoices.firstIndex(where: { $0.id == invoiceID }), amount > 0, amount <= invoices[index].outstanding else { return }
        invoices[index].paid += amount
        save()
    }

    func product(for barcode: String) -> Product? {
        products.first { Barcode.normalized($0.barcode) == Barcode.normalized(barcode) }
    }

    func reset() {
        customers = []; products = []; orders = []; purchases = []; invoices = []; visits = []
        seed()
    }
}
