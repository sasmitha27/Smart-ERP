import XCTest
@testable import SmartERPMobile

final class DomainTests: XCTestCase {
    func testBarcodeNormalization() {
        XCTAssertEqual(Barcode.normalized(" 0479123456789 "), "479123456789")
        XCTAssertEqual(Barcode.normalized(" ab-42 "), "AB-42")
    }

    func testDocumentTotal() {
        let line = LineItem(productID: UUID(), name: "Sample", quantity: 3, unitPrice: 125.50)
        XCTAssertEqual(line.total, 376.50)
        let order = SalesOrder(number: "TEST", customerID: UUID(), customerName: "Customer", lines: [line])
        XCTAssertEqual(order.total, 376.50)
    }

    @MainActor func testPartialReceiptCapsQuantity() {
        let store = DemoStore()
        store.reset()
        let product = store.products[0]
        let opening = product.stock
        let line = LineItem(productID: product.id, name: product.name, quantity: 5, unitPrice: product.cost)
        store.addPurchase(supplier: "Supplier", lines: [line])
        let purchaseID = store.purchases[0].id
        store.receive(purchaseID: purchaseID, quantities: [product.id: 2])
        store.receive(purchaseID: purchaseID, quantities: [product.id: 10])
        XCTAssertEqual(store.purchases[0].received[product.id], 5)
        XCTAssertEqual(store.products.first(where: { $0.id == product.id })?.stock, opening + 5)
        store.reset()
    }
}
