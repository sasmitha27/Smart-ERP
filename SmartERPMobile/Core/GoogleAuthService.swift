import Foundation
import Observation
import UIKit
import GoogleSignIn

struct GoogleAccount: Equatable {
    var projectID: String
    var uid: String
    var email: String
    var displayName: String
}

@MainActor @Observable
final class GoogleAuthService {
    var account: GoogleAccount?
    var isBusy = false
    var errorMessage: String?

    init() {
        if let saved = FirebaseSessionVault.read(), saved.provider == "google" {
            account = GoogleAccount(projectID: saved.projectID, uid: saved.localID,
                                    email: saved.email ?? "", displayName: saved.displayName ?? "Google account")
        }
    }

    func signIn(settings: FirebaseSettings) async {
        guard settings.isValid else { errorMessage = "Enter the Firebase project ID and Web API key first."; return }
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              clientID.hasSuffix(".apps.googleusercontent.com"),
              let scheme = (Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])?.first?["CFBundleURLSchemes"] as? [String],
              scheme.contains(clientID.split(separator: ".").reversed().joined(separator: ".")) else {
            errorMessage = "Set your Google iOS client ID and reversed URL scheme in SmartERPMobile/Info.plist."
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Could not open Google sign-in from this window."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let result { continuation.resume(returning: result) }
                    else { continuation.resume(throwing: FirebaseBackupError.response) }
                }
            }
            guard let idToken = result.user.idToken?.tokenString else { throw FirebaseBackupError.response }
            let session = try await exchangeGoogleToken(idToken, settings: settings)
            try FirebaseSessionVault.write(session)
            account = GoogleAccount(projectID: session.projectID, uid: session.localID,
                                    email: session.email ?? "", displayName: session.displayName ?? "Google account")
        } catch {
            GIDSignIn.sharedInstance.signOut()
            errorMessage = error.localizedDescription
        }
    }

    func validateSavedSignIn(settings: FirebaseSettings) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await FirebaseBackup(settings: settings).validateSignIn()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        FirebaseSessionVault.clear()
        account = nil
        errorMessage = nil
    }

    private func exchangeGoogleToken(_ idToken: String, settings: FirebaseSettings) async throws -> FirebaseSession {
        var endpoint = URLComponents(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp")!
        endpoint.queryItems = [URLQueryItem(name: "key", value: settings.apiKey)]
        var post = URLComponents()
        post.queryItems = [URLQueryItem(name: "id_token", value: idToken), URLQueryItem(name: "providerId", value: "google.com")]
        let payload: [String: Any] = ["postBody": post.percentEncodedQuery ?? "", "requestUri": "http://localhost",
                                      "returnSecureToken": true]
        var request = URLRequest(url: endpoint.url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirebaseBackupError.response }
        guard (200..<300).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (json?["error"] as? [String: Any])?["message"] as? String
            throw FirebaseBackupError.server(detail ?? "Firebase sign-in returned HTTP \(http.statusCode).")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = json["localId"] as? String,
              let token = json["refreshToken"] as? String else { throw FirebaseBackupError.response }
        return FirebaseSession(projectID: settings.projectID, localID: uid, refreshToken: token,
                               provider: "google", email: json["email"] as? String,
                               displayName: json["displayName"] as? String)
    }
}
