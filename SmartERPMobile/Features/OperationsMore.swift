import SwiftUI
import MapKit
import CoreLocation

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

struct TeamMapView: View {
    @Environment(DemoStore.self) private var store
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 6.9176, longitude: 79.8700), span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)))
    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                ForEach(store.visits) { visit in
                    Marker(visit.name, systemImage: "mappin", coordinate: CLLocationCoordinate2D(latitude: visit.latitude, longitude: visit.longitude))
                }
            }.frame(height: 360)
            List {
                Section("Sample assignments") {
                    ForEach(store.visits) { visit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visit.name).font(.headline)
                            Text(visit.address).foregroundStyle(.secondary)
                            Text("Scheduled \(visit.scheduledAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                        }
                    }
                }
                Section { Text("Live colleague location requires an authorized backend feed. No current location is shown here.").font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Team map")
    }
}

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

@MainActor @Observable
final class LocationSession: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorization: CLAuthorizationStatus = .notDetermined
    var latest: CLLocation?
    var active = false
    override init() { super.init(); manager.delegate = self; authorization = manager.authorizationStatus }
    func start() { active = true; manager.requestWhenInUseAuthorization(); if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.startUpdatingLocation() } }
    func stop() { active = false; manager.stopUpdatingLocation(); latest = nil }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { Task { @MainActor in authorization = manager.authorizationStatus; if active && (authorization == .authorizedWhenInUse || authorization == .authorizedAlways) { manager.startUpdatingLocation() } } }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { Task { @MainActor in if active { latest = locations.last } } }
}

struct WorkSessionView: View {
    @State private var location = LocationSession()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("Work session", subtitle: "You control when location is used")
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(location.active ? "Session active" : "Session off", systemImage: location.active ? "location.fill" : "location.slash")
                            .font(.title3.bold()).foregroundStyle(location.active ? Theme.green : .secondary)
                        Text("During a session, this demo requests foreground location and shows the latest reading on this device. It does not send location to a server.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let latest = location.latest {
                            Text("Latest: \(latest.coordinate.latitude.formatted(.number.precision(.fractionLength(4)))), \(latest.coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                                .font(.caption.monospacedDigit())
                        }
                        Button(location.active ? "End session" : "Start session") { location.active ? location.stop() : location.start() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }.padding()
        }
        .background(Theme.background)
        .navigationTitle("My location")
        .onDisappear { location.stop() }
    }
}

struct MoreView: View {
    @Environment(DemoStore.self) private var store
    @State private var resetConfirmation = false
    var body: some View {
        List {
            Section("Workspace") {
                Label("Inventolo Demo", systemImage: "building.2")
                Label("Local demo mode", systemImage: "iphone.gen3")
            }
            Section("Status") {
                LabeledContent("Last local save", value: store.lastSaved?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                LabeledContent("Pending server sync", value: "Unavailable")
                Text("The Inventolo API is not configured. No records are sent to a server.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Insights") { NavigationLink { ReportsView() } label: { Label("Reports", systemImage: "chart.bar.xaxis") } }
            Section("Data") { Button("Reset demo data", role: .destructive) { resetConfirmation = true } }
            Section("About") { Text("SmartERP Mobile · Native iOS preview").foregroundStyle(.secondary) }
        }
        .navigationTitle("More")
        .confirmationDialog("Reset all local demo records?", isPresented: $resetConfirmation) {
            Button("Reset demo data", role: .destructive) { store.reset() }
        }
    }
}
