import Foundation
import Security

struct FirebaseSettings {
    var projectID: String
    var apiKey: String

    var isValid: Bool {
        !projectID.isEmpty && !apiKey.isEmpty && projectID.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
    }
}

enum FirebaseBackupError: LocalizedError {
    case configuration, response, server(String), noBackup
    var errorDescription: String? {
        switch self {
        case .configuration: "Enter a Firebase project ID and Web API key."
        case .response: "Firebase returned an unexpected response."
        case .server(let detail): detail
        case .noBackup: "No cloud backup exists for this Google account."
        }
    }
}

struct FirebaseSession: Codable {
    var projectID: String
    var localID: String
    var refreshToken: String
    var provider: String?
    var email: String?
    var displayName: String?
}

enum FirebaseSessionVault {
    static let service = "com.smarterp.firebase.backup"
    static func read() -> FirebaseSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(FirebaseSession.self, from: data)
    }
    static func clear() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
    }
    static func write(_ session: FirebaseSession) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        var values = query
        values[kSecValueData as String] = try JSONEncoder().encode(session)
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else { throw FirebaseBackupError.response }
    }
}

struct FirebaseBackup {
    let settings: FirebaseSettings
    var session: URLSession = .shared

    private func request(_ url: URL, method: String, body: Data? = nil, bearer: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FirebaseBackupError.response }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 { throw FirebaseBackupError.noBackup }
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (error?["error"] as? [String: Any])?["message"] as? String
            throw FirebaseBackupError.server(detail ?? "Firebase returned HTTP \(http.statusCode).")
        }
        return data
    }

    private func authenticatedUser() async throws -> (uid: String, token: String) {
        guard settings.isValid else { throw FirebaseBackupError.configuration }
        guard let saved = FirebaseSessionVault.read(), saved.projectID == settings.projectID,
              saved.provider == "google" else {
            throw FirebaseBackupError.server("Sign in with Google to use Firebase backup.")
        }
        var parts = URLComponents(string: "https://securetoken.googleapis.com/v1/token")!
        parts.queryItems = [URLQueryItem(name: "key", value: settings.apiKey)]
        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token"),
                           URLQueryItem(name: "refresh_token", value: saved.refreshToken)]
        var refreshRequest = URLRequest(url: parts.url!)
        refreshRequest.httpMethod = "POST"
        refreshRequest.timeoutInterval = 30
        refreshRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        refreshRequest.httpBody = Data((form.percentEncodedQuery ?? "").utf8)
        let (data, response) = try await session.data(for: refreshRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["id_token"] as? String else {
            throw FirebaseBackupError.server("Google sign-in expired. Sign out and sign in again.")
        }
        if let refreshed = json["refresh_token"] as? String {
            var next = saved
            next.refreshToken = refreshed
            try FirebaseSessionVault.write(next)
        }
        return (saved.localID, token)
    }

    private func documentURL(uid: String) throws -> URL {
        guard settings.isValid else { throw FirebaseBackupError.configuration }
        guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(settings.projectID)/databases/(default)/documents/users/\(uid)/backups/current") else {
            throw FirebaseBackupError.configuration
        }
        return url
    }

    func validateSignIn() async throws {
        _ = try await authenticatedUser()
    }

    func upload(_ snapshot: Data) async throws {
        let user = try await authenticatedUser()
        let fields: [String: Any] = ["fields": ["payload": ["stringValue": snapshot.base64EncodedString()],
                                                  "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: .now)]]]
        let body = try JSONSerialization.data(withJSONObject: fields)
        _ = try await request(documentURL(uid: user.uid), method: "PATCH", body: body, bearer: user.token)
    }

    func download() async throws -> Data {
        let user = try await authenticatedUser()
        let data = try await request(documentURL(uid: user.uid), method: "GET", bearer: user.token)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any],
              let payload = fields["payload"] as? [String: String],
              let encoded = payload["stringValue"],
              let snapshot = Data(base64Encoded: encoded) else { throw FirebaseBackupError.response }
        return snapshot
    }
}
