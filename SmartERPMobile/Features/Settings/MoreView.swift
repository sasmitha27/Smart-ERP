import SwiftUI

struct MoreView: View {
    @Environment(DemoStore.self) private var store
    @Environment(GoogleAuthService.self) private var auth
    @AppStorage("firebaseProjectID") private var projectID = ""
    @State private var resetConfirmation = false
    var body: some View {
        List {
            Section("Workspace") {
                Label("Inventolo Demo", systemImage: "building.2")
                Label("Local demo mode", systemImage: "iphone.gen3")
            }
            Section("Status") {
                LabeledContent("Last local save", value: store.lastSaved?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                Text("Firebase backup runs only when you choose upload or restore.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Cloud") {
                NavigationLink { GoogleLoginView() } label: { Label(auth.account?.projectID == projectID && auth.account?.email.isEmpty == false ? auth.account!.email : "Google sign-in", systemImage: "person.crop.circle") }
                NavigationLink { FirebaseBackupView() } label: { Label("Firebase backup", systemImage: "externaldrive.badge.icloud") }
            }
            Section("Insights") {
                NavigationLink { AssistantView() } label: { Label("Smart Assistant", systemImage: "sparkles") }
                NavigationLink { ReportsView() } label: { Label("Reports", systemImage: "chart.bar.xaxis") }
            }
            Section("Data") { Button("Reset demo data", role: .destructive) { resetConfirmation = true } }
            Section("About") { Text("SmartERP Mobile · Native iOS preview").foregroundStyle(.secondary) }
        }
        .navigationTitle("More")
        .confirmationDialog("Reset all local demo records?", isPresented: $resetConfirmation) {
            Button("Reset demo data", role: .destructive) { store.reset() }
        }
    }
}
