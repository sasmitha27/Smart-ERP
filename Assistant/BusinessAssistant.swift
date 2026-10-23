import Foundation

struct BusinessSnapshot: Sendable {
    struct ProductSummary: Sendable {
        let name: String
        let stock: Int
        let reorderLevel: Int
        let cost: Decimal
    }

    struct InvoiceSummary: Sendable {
        let customerName: String
        let total: Decimal
        let paid: Decimal
        let outstanding: Decimal
    }

    let products: [ProductSummary]
    let invoices: [InvoiceSummary]
    let orderCount: Int
    let orderValue: Decimal
    let purchaseCount: Int
    let plannedVisitCount: Int
    let completedVisitCount: Int

    @MainActor
    init(store: DemoStore) {
        products = store.products.map {
            ProductSummary(name: $0.name, stock: $0.stock, reorderLevel: $0.reorderLevel, cost: $0.cost)
        }
        invoices = store.invoices.map {
            InvoiceSummary(customerName: $0.customerName, total: $0.total, paid: $0.paid, outstanding: $0.outstanding)
        }
        orderCount = store.orders.count
        orderValue = store.orders.reduce(0) { $0 + $1.total }
        purchaseCount = store.purchases.count
        plannedVisitCount = store.visits.count
        completedVisitCount = store.visits.filter { $0.completedAt != nil }.count
    }

    init(
        products: [ProductSummary],
        invoices: [InvoiceSummary],
        orderCount: Int,
        orderValue: Decimal,
        purchaseCount: Int,
        plannedVisitCount: Int,
        completedVisitCount: Int
    ) {
        self.products = products
        self.invoices = invoices
        self.orderCount = orderCount
        self.orderValue = orderValue
        self.purchaseCount = purchaseCount
        self.plannedVisitCount = plannedVisitCount
        self.completedVisitCount = completedVisitCount
    }
}

struct BusinessAnswer: Sendable, Equatable {
    let title: String
    let body: String
    let verifiedFacts: String
}

enum BusinessAssistant {
    static func answer(question: String, snapshot: BusinessSnapshot) -> BusinessAnswer {
        let normalized = question.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if containsAny(normalized, terms: ["low stock", "reorder", "running low", "inventory alert"]) {
            return lowStockAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["outstanding", "unpaid", "receivable", "owe", "balance"]) {
            return receivablesAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["largest customer", "top customer", "best customer"]) {
            return topCustomerAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["sales", "revenue", "invoice", "payment"]) {
            return salesAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["order", "purchase"]) {
            return ordersAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["visit", "field", "appointment"]) {
            return visitsAnswer(snapshot)
        }
        if containsAny(normalized, terms: ["summary", "overview", "morning", "business", "today"]) {
            return summaryAnswer(snapshot)
        }

        return BusinessAnswer(
            title: "What I can help with",
            body: "Ask me about sales, unpaid invoices, low-stock products, orders, top customers, visits, or request a business summary.",
            verifiedFacts: "No business calculation was requested."
        )
    }

    static func summaryAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let invoiceValue = snapshot.invoices.reduce(Decimal.zero) { $0 + $1.total }
        let outstanding = snapshot.invoices.reduce(Decimal.zero) { $0 + $1.outstanding }
        let lowStock = snapshot.products.filter { $0.stock <= $0.reorderLevel }
        let body = "Invoice value is \(Money.format(invoiceValue)), with \(Money.format(outstanding)) outstanding. There are \(snapshot.orderCount) sales orders and \(lowStock.count) low-stock products. \(snapshot.completedVisitCount) of \(snapshot.plannedVisitCount) planned visits are complete."
        return BusinessAnswer(title: "Business summary", body: body, verifiedFacts: body)
    }

    private static func lowStockAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let products = snapshot.products
            .filter { $0.stock <= $0.reorderLevel }
            .sorted { ($0.stock - $0.reorderLevel) < ($1.stock - $1.reorderLevel) }

        guard !products.isEmpty else {
            let body = "No products are currently at or below their reorder level."
            return BusinessAnswer(title: "Inventory looks healthy", body: body, verifiedFacts: body)
        }

        let list = products.map { "\($0.name): \($0.stock) in stock, reorder level \($0.reorderLevel)" }.joined(separator: "\n")
        let body = "\(products.count) product\(products.count == 1 ? " is" : "s are") at or below the reorder level:\n\(list)"
        return BusinessAnswer(title: "Low-stock products", body: body, verifiedFacts: body)
    }

    private static func receivablesAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let unpaid = snapshot.invoices.filter { $0.outstanding > 0 }
        let total = unpaid.reduce(Decimal.zero) { $0 + $1.outstanding }
        let customerBalances = Dictionary(grouping: unpaid, by: \.customerName)
            .map { (name: $0.key, amount: $0.value.reduce(Decimal.zero) { $0 + $1.outstanding }) }
            .sorted { $0.amount > $1.amount }

        guard !customerBalances.isEmpty else {
            let body = "There are no outstanding demo invoice balances."
            return BusinessAnswer(title: "Receivables", body: body, verifiedFacts: body)
        }

        let details = customerBalances.prefix(3).map { "\($0.name): \(Money.format($0.amount))" }.joined(separator: "\n")
        let body = "Total outstanding is \(Money.format(total)) across \(unpaid.count) invoice\(unpaid.count == 1 ? "" : "s").\n\(details)"
        return BusinessAnswer(title: "Outstanding receivables", body: body, verifiedFacts: body)
    }

    private static func topCustomerAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let totals = Dictionary(grouping: snapshot.invoices, by: \.customerName)
            .map { (name: $0.key, amount: $0.value.reduce(Decimal.zero) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }

        guard let top = totals.first else {
            let body = "There are no demo invoices yet, so a top customer cannot be identified."
            return BusinessAnswer(title: "Top customer", body: body, verifiedFacts: body)
        }

        let body = "\(top.name) has the highest invoiced value at \(Money.format(top.amount))."
        return BusinessAnswer(title: "Top customer", body: body, verifiedFacts: body)
    }

    private static func salesAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let total = snapshot.invoices.reduce(Decimal.zero) { $0 + $1.total }
        let paid = snapshot.invoices.reduce(Decimal.zero) { $0 + $1.paid }
        let outstanding = snapshot.invoices.reduce(Decimal.zero) { $0 + $1.outstanding }
        let body = "\(snapshot.invoices.count) demo invoice\(snapshot.invoices.count == 1 ? "" : "s") total \(Money.format(total)). Payments are \(Money.format(paid)), leaving \(Money.format(outstanding)) outstanding."
        return BusinessAnswer(title: "Sales snapshot", body: body, verifiedFacts: body)
    }

    private static func ordersAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let body = "There are \(snapshot.orderCount) sales orders worth \(Money.format(snapshot.orderValue)) and \(snapshot.purchaseCount) purchase orders in this workspace."
        return BusinessAnswer(title: "Orders and purchasing", body: body, verifiedFacts: body)
    }

    private static func visitsAnswer(_ snapshot: BusinessSnapshot) -> BusinessAnswer {
        let remaining = max(0, snapshot.plannedVisitCount - snapshot.completedVisitCount)
        let body = "\(snapshot.completedVisitCount) of \(snapshot.plannedVisitCount) planned visits are complete. \(remaining) remain."
        return BusinessAnswer(title: "Field activity", body: body, verifiedFacts: body)
    }

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }
}

