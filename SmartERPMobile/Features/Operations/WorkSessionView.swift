import SwiftUI
import CoreLocation

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
