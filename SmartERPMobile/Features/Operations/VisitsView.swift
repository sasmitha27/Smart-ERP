import SwiftUI

struct VisitsView: View {
    @Environment(DemoStore.self) private var store
    @State private var adding = false
    var body: some View {
        List {
            ForEach(store.visits) { visit in
                VStack(alignment: .leading, spacing: 5) {
                    HStack { Text(visit.name).font(.headline); Spacer(); if visit.completedAt != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green) } }
                    Text(visit.address).foregroundStyle(.secondary)
                    Text(visit.scheduledAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    if visit.completedAt == nil { Button("Confirm demo visit") {
                        if let index = store.visits.firstIndex(where: { $0.id == visit.id }) { store.visits[index].completedAt = .now; store.save() }
                    }.font(.subheadline.weight(.semibold)) }
                }.padding(.vertical, 5)
            }
        }
        .navigationTitle("Visits")
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add visit") }
        .sheet(isPresented: $adding) { NavigationStack { VisitForm() } }
    }
}

struct VisitForm: View {
    @Environment(DemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var date = Date.now.addingTimeInterval(3600)
    var body: some View {
        Form {
            Section("Destination") {
                TextField("Name", text: $name)
                TextField("Address", text: $address)
                TextField("Latitude", text: $latitude).keyboardType(.decimalPad)
                TextField("Longitude", text: $longitude).keyboardType(.decimalPad)
                DatePicker("Expected visit", selection: $date)
            }
            Section { Text("This is a local demo assignment. It does not start geofence monitoring or notify a manager.").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("Add location")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") {
                guard !name.isEmpty, let lat = Double(latitude), let lon = Double(longitude), (-90...90).contains(lat), (-180...180).contains(lon) else { store.message = "Enter a name and valid coordinates."; return }
                store.visits.insert(Visit(name: name, address: address, latitude: lat, longitude: lon, scheduledAt: date), at: 0)
                store.save(); dismiss()
            } }
        }
    }
}
