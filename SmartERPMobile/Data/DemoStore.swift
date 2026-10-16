import Foundation
import Observation

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

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SmartERP/demo-data.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            customers = snapshot.customers
            products = snapshot.products
            orders = snapshot.orders
            purchases = snapshot.purchases
            invoices = snapshot.invoices
            visits = snapshot.visits
            lastSaved = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        } else {
            seed()
        }
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
        let snapshot = Snapshot(customers: customers, products: products, orders: orders, purchases: purchases, invoices: invoices, visits: visits)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            lastSaved = .now
        } catch {
            message = "Could not save local demo data: \(error.localizedDescription)"
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
