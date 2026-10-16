import Foundation

enum Money {
    static let currency = "LKR"
    static func format(_ value: Decimal) -> String {
        value.formatted(.currency(code: currency))
    }
}

struct Customer: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var phone: String
    var email: String
    var address: String
    var type: String = "Business"
    var notes: String = ""
}

struct Product: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var sku: String
    var barcode: String
    var category: String
    var price: Decimal
    var cost: Decimal
    var stock: Int
    var reorderLevel: Int = 5
}

struct LineItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var productID: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var total: Decimal { unitPrice * Decimal(quantity) }
}

enum DocumentStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case confirmed = "Confirmed in demo"
    case received = "Received in demo"
}

struct SalesOrder: Identifiable, Codable {
    var id: UUID = UUID()
    var number: String
    var customerID: UUID
    var customerName: String
    var createdAt: Date = .now
    var lines: [LineItem]
    var status: DocumentStatus = .draft
    var total: Decimal { lines.reduce(0) { $0 + $1.total } }
}

struct PurchaseOrder: Identifiable, Codable {
    var id: UUID = UUID()
    var number: String
    var supplier: String
    var createdAt: Date = .now
    var lines: [LineItem]
    var received: [UUID: Int] = [:]
    var total: Decimal { lines.reduce(0) { $0 + $1.total } }
    var complete: Bool { lines.allSatisfy { received[$0.productID, default: 0] >= $0.quantity } }
}

struct Invoice: Identifiable, Codable {
    var id: UUID = UUID()
    var number: String
    var orderID: UUID
    var customerName: String
    var createdAt: Date = .now
    var lines: [LineItem]
    var paid: Decimal = 0
    var total: Decimal { lines.reduce(0) { $0 + $1.total } }
    var outstanding: Decimal { max(0, total - paid) }
}

struct Visit: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var scheduledAt: Date
    var completedAt: Date? = nil
    var notes: String = ""
}

enum Barcode {
    static func normalized(_ raw: String) -> String {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count == 13 && cleaned.hasPrefix("0") && cleaned.allSatisfy(\.isNumber) {
            return String(cleaned.dropFirst())
        }
        return cleaned.uppercased()
    }
}
