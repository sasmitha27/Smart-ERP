import Foundation
import Testing
@testable import SmartERPMobile

@Suite("Demo store snapshots", .serialized)
@MainActor
struct DemoStoreSnapshotTests {
    @Test("Exported data restores all business records")
    func snapshotRoundTrip() throws {
        let store = DemoStore()
        store.reset()
        let customer = Customer(
            name: "Snapshot Customer",
            phone: "0112345678",
            email: "snapshot@example.com",
            address: "Colombo"
        )
        store.addCustomer(customer)
        let exported = try store.exportSnapshot()

        store.reset()
        #expect(!store.customers.contains { $0.id == customer.id })

        try store.importSnapshot(exported)

        #expect(store.customers.contains { $0 == customer })
        #expect(!store.products.isEmpty)
        #expect(!store.visits.isEmpty)
    }

    @Test("Malformed snapshots are rejected without replacing current records")
    func malformedSnapshot() {
        let store = DemoStore()
        store.reset()
        let customerIDs = store.customers.map(\.id)

        #expect(throws: (any Error).self) {
            try store.importSnapshot(Data("not-json".utf8))
        }
        #expect(store.customers.map(\.id) == customerIDs)
    }
}
