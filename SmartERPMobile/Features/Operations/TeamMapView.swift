import SwiftUI
import MapKit

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
