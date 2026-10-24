import SwiftUI

struct FirebaseBackupView: View {
    @Environment(DemoStore.self) private var store
    @Environment(GoogleAuthService.self) private var auth
    @AppStorage("firebaseProjectID") private var projectID = ""
    @AppStorage("firebaseAPIKey") private var apiKey = ""
    @State private var busy = false
    @State private var status = ""
    @State private var confirmRestore = false

    private var backup: FirebaseBackup { FirebaseBackup(settings: FirebaseSettings(projectID: projectID.trimmingCharacters(in: .whitespacesAndNewlines), apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))) }

    var body: some View {
        Form {
            Section("Firebase project") {
                TextField("Project ID", text: $projectID).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Web API key", text: $apiKey).textInputAutocapitalization(.never)
                Text("Enable Google Authentication and create a Firestore database in the Firebase console.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Account") {
                if let account = auth.account, account.projectID == backup.settings.projectID {
                    Text(account.email.isEmpty ? account.displayName : account.email)
                } else {
                    NavigationLink("Sign in with Google") { GoogleLoginView() }
                }
            }
            Section("Cloud backup") {
                Button("Upload local snapshot") { Task { await upload() } }.disabled(busy || !backup.settings.isValid || auth.account?.projectID != backup.settings.projectID)
                Button("Restore cloud snapshot") { confirmRestore = true }.disabled(busy || !backup.settings.isValid || auth.account?.projectID != backup.settings.projectID)
                if busy { ProgressView() }
                if !status.isEmpty { Text(status).font(.caption) }
                Text("Upload and restore are manual. Restoring replaces all local demo records on this device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Firebase backup")
        .confirmationDialog("Replace all local records with the cloud snapshot?", isPresented: $confirmRestore) {
            Button("Restore and replace", role: .destructive) { Task { await restore() } }
        }
    }

    private func upload() async {
        busy = true
        defer { busy = false }
        do {
            try await backup.upload(store.exportSnapshot())
            status = "Cloud backup uploaded successfully."
        } catch { status = error.localizedDescription }
    }

    private func restore() async {
        busy = true
        defer { busy = false }
        do {
            try store.importSnapshot(await backup.download())
            status = "Cloud backup restored successfully."
        } catch { status = error.localizedDescription }
    }
}
