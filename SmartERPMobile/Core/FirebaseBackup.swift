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
        case .noBackup: "No cloud backup exists for this installation."
        }
    }
}

private struct FirebaseSession: Codable {
    var projectID: String
    var localID: String
    var refreshToken: String
}

private enum FirebaseSessionVault {
    static let service = "com.smarterp.firebase.backup"
    static func read() -> FirebaseSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(FirebaseSession.self, from: data)
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
        if let saved = FirebaseSessionVault.read(), saved.projectID == settings.projectID {
            var parts = URLComponents(string: "https://securetoken.googleapis.com/v1/token")!
            parts.queryItems = [URLQueryItem(name: "key", value: settings.apiKey)]
            let form = "grant_type=refresh_token&refresh_token=\(saved.refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            var refreshRequest = URLRequest(url: parts.url!)
            refreshRequest.httpMethod = "POST"
            refreshRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            refreshRequest.httpBody = Data(form.utf8)
            if let (data, response) = try? await session.data(for: refreshRequest),
               let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["id_token"] as? String {
                if let refreshed = json["refresh_token"] as? String {
                    try FirebaseSessionVault.write(FirebaseSession(projectID: settings.projectID, localID: saved.localID, refreshToken: refreshed))
                }
                return (saved.localID, token)
            }
            throw FirebaseBackupError.server("Could not refresh this installation’s Firebase sign-in. The existing backup was not changed.")
        }
        var parts = URLComponents(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp")!
        parts.queryItems = [URLQueryItem(name: "key", value: settings.apiKey)]
        let data = try await request(parts.url!, method: "POST", body: Data("{}".utf8))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uid = json["localId"] as? String,
              let token = json["idToken"] as? String,
              let refresh = json["refreshToken"] as? String else { throw FirebaseBackupError.response }
        try FirebaseSessionVault.write(FirebaseSession(projectID: settings.projectID, localID: uid, refreshToken: refresh))
        return (uid, token)
    }

    private func documentURL(uid: String) throws -> URL {
        guard settings.isValid else { throw FirebaseBackupError.configuration }
        guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(settings.projectID)/databases/(default)/documents/users/\(uid)/backups/current") else {
            throw FirebaseBackupError.configuration
        }
        return url
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
