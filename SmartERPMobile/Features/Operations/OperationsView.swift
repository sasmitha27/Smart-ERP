import SwiftUI

struct OperationsView: View {
    var body: some View {
        List {
            Section("Purchasing") { NavigationLink { PurchaseListView() } label: { Label("Purchase orders & receiving", systemImage: "shippingbox") } }
            Section("Field sales") {
                NavigationLink { TeamMapView() } label: { Label("Sales team map", systemImage: "map") }
                NavigationLink { VisitsView() } label: { Label("Assigned visits", systemImage: "mappin.and.ellipse") }
                NavigationLink { WorkSessionView() } label: { Label("My work session", systemImage: "location.circle") }
            }
            Section { Text("Map team positions are sample data. Your device location is only requested during an explicit work session.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Operations")
    }
}
