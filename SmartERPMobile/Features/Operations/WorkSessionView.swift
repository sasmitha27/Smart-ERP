import SwiftUI
import CoreLocation

@MainActor @Observable
final class LocationSession: NSObject, CLLocationManagerDelegate {
    static let shared = LocationSession()
    private let manager = CLLocationManager()
    var authorization: CLAuthorizationStatus = .notDetermined
    var latest: CLLocation?
    var active = false
    private var requested = false
    override init() { super.init(); manager.delegate = self; authorization = manager.authorizationStatus }
    func start() { requested = true; manager.requestWhenInUseAuthorization(); authorization = manager.authorizationStatus; active = authorization == .authorizedWhenInUse || authorization == .authorizedAlways; if active { manager.startUpdatingLocation() } }
    func stop() { requested = false; active = false; manager.stopUpdatingLocation(); latest = nil }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { Task { @MainActor in authorization = manager.authorizationStatus; if requested && (authorization == .authorizedWhenInUse || authorization == .authorizedAlways) { active = true; manager.startUpdatingLocation() } else { active = false; manager.stopUpdatingLocation() } } }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { Task { @MainActor in if active { latest = locations.last } } }
}

struct WorkSessionView: View {
    @Environment(DemoStore.self) private var store
    @State private var location = LocationSession.shared
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
                        Button(location.active ? "End session" : "Start session") {
                            if location.active {
                                location.stop()
                                Task { await WorkActivityManager.shared.end() }
                            } else {
                                location.start()
                                if location.active { startActivity() }
                            }
                        }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }.padding()
        }
        .background(Theme.background)
        .navigationTitle("My location")
        .onChange(of: location.authorization) { _, newValue in
            if location.active && (newValue == .authorizedWhenInUse || newValue == .authorizedAlways) { startActivity() }
        }

    }
    private func startActivity() {
        let next = store.visits.filter { $0.completedAt == nil && $0.scheduledAt >= .now }.min { $0.scheduledAt < $1.scheduledAt }
        do { try WorkActivityManager.shared.start(nextVisit: next?.name) }
        catch { store.message = "Could not start Live Activity: \(error.localizedDescription)" }
    }

}
