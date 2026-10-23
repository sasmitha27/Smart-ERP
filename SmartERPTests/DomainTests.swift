import Foundation
import Testing
@testable import SmartERPMobile

@Suite("Domain models")
struct DomainModelTests {
    /// Barcode input is trimmed and alphabetic identifiers are made case-insensitive.
    @Test(
        "Barcode normalization handles supported input forms",
        arguments: [
            (" 0479123456789 ", "479123456789"),
            (" ab-42 ", "AB-42"),
            ("  12345\n", "12345"),
            ("012345678901A", "012345678901A")
        ]
    )
    func barcodeNormalization(raw: String, expected: String) {
        #expect(Barcode.normalized(raw) == expected)
    }

    /// Line and order totals retain Decimal precision and aggregate every line.
    @Test("Document totals include all quantities and lines")
    func documentTotals() {
        let productID = UUID()
        let first = LineItem(productID: productID, name: "Sample", quantity: 3, unitPrice: 125.50)
        let second = LineItem(productID: productID, name: "Discounted", quantity: 2, unitPrice: 0.25)
        let order = SalesOrder(number: "TEST", customerID: UUID(), customerName: "Customer", lines: [first, second])

        #expect(first.total == 376.50)
        #expect(order.total == 377.00)
        #expect(SalesOrder(number: "EMPTY", customerID: UUID(), customerName: "Customer", lines: []).total == 0)
    }

    /// A purchase is complete only after every line has been received in full.
    @Test("Purchase completion accounts for every line")
    func purchaseCompletion() {
        let firstID = UUID()
        let secondID = UUID()
        let lines = [
            LineItem(productID: firstID, name: "First", quantity: 2, unitPrice: 10),
            LineItem(productID: secondID, name: "Second", quantity: 1, unitPrice: 20)
        ]

        #expect(!PurchaseOrder(number: "PO", supplier: "Supplier", lines: lines).complete)
        #expect(!PurchaseOrder(number: "PO", supplier: "Supplier", lines: lines, received: [firstID: 2]).complete)
        #expect(PurchaseOrder(number: "PO", supplier: "Supplier", lines: lines, received: [firstID: 2, secondID: 1]).complete)
    }

    /// Outstanding balances never become negative, even for an overpaid decoded invoice.
    @Test("Invoice outstanding balance is clamped to zero")
    func invoiceOutstandingBalance() {
        let line = LineItem(productID: UUID(), name: "Sample", quantity: 2, unitPrice: 50)

        #expect(Invoice(number: "INV-1", orderID: UUID(), customerName: "Customer", lines: [line], paid: 25).outstanding == 75)
        #expect(Invoice(number: "INV-2", orderID: UUID(), customerName: "Customer", lines: [line], paid: 150).outstanding == 0)
    }

    /// Non-HTTPS service endpoints are rejected before any network request is possible.
    @Test("API client requires HTTPS")
    func apiClientRequiresHTTPS() {
        #expect(throws: APIError.self) {
            try APIClient(baseURL: try #require(URL(string: "http://example.com")))
        }
    }
}

/// DemoStore writes a shared demo snapshot, so these tests run serially to keep their fixtures isolated.
@Suite("Demo store", .serialized)
@MainActor
struct DemoStoreTests {
    private func freshStore() -> DemoStore {
        let store = DemoStore()
        store.reset()
        return store
    }

    @Test("Empty orders are ignored and valid orders are numbered")
    func addingOrders() {
        let store = freshStore()
        let customer = store.customers[0]

        store.addOrder(customer: customer, lines: [])
        #expect(store.orders.isEmpty)

        let product = store.products[0]
        let line = LineItem(productID: product.id, name: product.name, quantity: 1, unitPrice: product.price)
        store.addOrder(customer: customer, lines: [line])

        #expect(store.orders.count == 1)
        #expect(store.orders[0].number == "DEMO-SO-0001")
        #expect(store.orders[0].customerID == customer.id)
    }

    @Test("Purchases require a supplier and at least one line")
    func purchaseValidation() {
        let store = freshStore()
        let product = store.products[0]
        let line = LineItem(productID: product.id, name: product.name, quantity: 1, unitPrice: product.cost)

        store.addPurchase(supplier: "   ", lines: [line])
        store.addPurchase(supplier: "Supplier", lines: [])
        #expect(store.purchases.isEmpty)

        store.addPurchase(supplier: "Supplier", lines: [line])
        #expect(store.purchases.count == 1)
        #expect(store.purchases[0].number == "DEMO-PO-0001")
    }

    @Test("Receipts reject negative quantities and cap quantities at the amount ordered")
    func receivingPurchases() {
        let store = freshStore()
        let product = store.products[0]
        let openingStock = product.stock
        let line = LineItem(productID: product.id, name: product.name, quantity: 5, unitPrice: product.cost)
        store.addPurchase(supplier: "Supplier", lines: [line])
        let purchaseID = store.purchases[0].id

        store.receive(purchaseID: purchaseID, quantities: [product.id: -1])
        #expect(store.purchases[0].received[product.id] == nil)

        store.receive(purchaseID: purchaseID, quantities: [product.id: 2])
        store.receive(purchaseID: purchaseID, quantities: [product.id: 10])

        #expect(store.purchases[0].received[product.id] == 5)
        #expect(store.purchases[0].complete)
        #expect(store.products.first(where: { $0.id == product.id })?.stock == openingStock + 5)
    }

    @Test("An order can produce only one invoice")
    func invoiceCreationIsIdempotent() {
        let store = freshStore()
        let customer = store.customers[0]
        let product = store.products[0]
        let line = LineItem(productID: product.id, name: product.name, quantity: 1, unitPrice: product.price)
        store.addOrder(customer: customer, lines: [line])
        let orderID = store.orders[0].id

        store.createInvoice(orderID: UUID())
        #expect(store.invoices.isEmpty)

        store.createInvoice(orderID: orderID)
        store.createInvoice(orderID: orderID)

        #expect(store.invoices.count == 1)
        #expect(store.invoices[0].orderID == orderID)
        #expect(store.invoices[0].number == "DEMO-INV-0001")
    }

    @Test("Payments must be positive and cannot exceed the outstanding balance")
    func paymentValidation() {
        let store = freshStore()
        let customer = store.customers[0]
        let product = store.products[0]
        let line = LineItem(productID: product.id, name: product.name, quantity: 1, unitPrice: 100)
        store.addOrder(customer: customer, lines: [line])
        store.createInvoice(orderID: store.orders[0].id)
        let invoiceID = store.invoices[0].id

        store.recordPayment(invoiceID: invoiceID, amount: 0)
        store.recordPayment(invoiceID: invoiceID, amount: 101)
        #expect(store.invoices[0].paid == 0)

        store.recordPayment(invoiceID: invoiceID, amount: 40)
        #expect(store.invoices[0].paid == 40)
        #expect(store.invoices[0].outstanding == 60)

        store.recordPayment(invoiceID: invoiceID, amount: 60)
        #expect(store.invoices[0].outstanding == 0)
    }

    @Test("Product lookup uses normalized barcode values")
    func productLookup() {
        let store = freshStore()
        let product = store.products[0]

        #expect(store.product(for: "  \(product.barcode)\n")?.id == product.id)
        #expect(store.product(for: "missing") == nil)
    }
}
