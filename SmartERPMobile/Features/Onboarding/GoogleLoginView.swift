import SwiftUI

struct GoogleLoginView: View {
    @Environment(DemoStore.self) private var store
    @Environment(GoogleAuthService.self) private var auth
    @AppStorage("firebaseProjectID") private var projectID = ""
    @AppStorage("firebaseAPIKey") private var apiKey = ""

    private var settings: FirebaseSettings {
        FirebaseSettings(projectID: projectID.trimmingCharacters(in: .whitespacesAndNewlines),
                         apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        Form {
            Section("Firebase project") {
                TextField("Project ID", text: $projectID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Web API key", text: $apiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Enable Google as a sign-in provider in Firebase Authentication. Add your iOS OAuth client ID and reversed URL scheme to SmartERPMobile/Info.plist.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Google account") {
                if let account = auth.account, account.projectID == settings.projectID {
                    LabeledContent("Saved account", value: account.displayName)
                    if !account.email.isEmpty { Text(account.email).font(.subheadline).foregroundStyle(.secondary) }
                    Button("Continue to app") {
                        Task {
                            if await auth.validateSavedSignIn(settings: settings) {
                                store.switchWorkspace(to: account)
                                store.hasEntered = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isBusy)
                    Button("Sign out", role: .destructive) {
                        auth.signOut()
                        store.switchWorkspace(to: nil)
                        store.hasEntered = false
                    }
                } else {
                    Button {
                        Task {
                            await auth.signIn(settings: settings)
                            if let account = auth.account, account.projectID == settings.projectID {
                                store.switchWorkspace(to: account)
                                store.hasEntered = true
                            }
                        }
                    } label: {
                        Label("Sign in with Google", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isBusy || !settings.isValid)
                    .frame(height: 50)
                }
                if auth.isBusy { ProgressView("Signing in…") }
                if let error = auth.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Text("Each Google account has a separate local workspace. Cloud backup runs only when you choose upload or restore.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Google sign-in")
    }
}
