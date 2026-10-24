import SwiftUI
import MapKit

struct TeamMapView: View {
    @Environment(DemoStore.self) private var store
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedVisitID: UUID?

    private var selectedVisit: Visit? { store.visits.first { $0.id == selectedVisitID } }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position, selection: $selectedVisitID) {
                ForEach(store.visits) { visit in
                    Marker(visit.name, systemImage: visit.completedAt == nil ? "mappin.circle.fill" : "checkmark.circle.fill", coordinate: CLLocationCoordinate2D(latitude: visit.latitude, longitude: visit.longitude))
                        .tag(visit.id)
                }
                UserAnnotation()
            }
            .mapControls { MapCompass(); MapScaleView(); MapUserLocationButton() }
            .frame(minHeight: 300)
            if let visit = selectedVisit {
                VStack(alignment: .leading, spacing: 8) {
                    Text(visit.name).font(.headline)
                    Text(visit.address).font(.subheadline).foregroundStyle(.secondary)
                    Text(visit.scheduledAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                    Button("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond") {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: visit.latitude, longitude: visit.longitude)))
                        item.name = visit.name
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    }.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            List {
                Section("Assigned visits") {
                    ForEach(store.visits) { visit in
                        Button {
                            selectedVisitID = visit.id
                            position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: visit.latitude, longitude: visit.longitude), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(visit.name).font(.headline)
                                Text(visit.address).foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Visit map")
        .onAppear {
            if let first = store.visits.first {
                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
            }
        }
    }
}
