import Foundation
import Security

enum APIError: Error, LocalizedError {
    case invalidURL, insecureURL, unauthenticated, server(Int), invalidResponse
    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid service URL"
        case .insecureURL: "HTTPS is required"
        case .unauthenticated: "Sign in is required"
        case .server(let code): "Server returned \(code)"
        case .invalidResponse: "Unexpected server response"
        }
    }
}

struct APIClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) throws {
        guard baseURL.scheme == "https" else { throw APIError.insecureURL }
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable>(path: String, method: String = "GET", token: String?, tenantID: String?, branchID: String?, body: Data? = nil, response: Response.Type) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              url.scheme == "https", url.host == baseURL.host else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let tenantID { request.setValue(tenantID, forHTTPHeaderField: "X-Tenant-ID") }
        if let branchID { request.setValue(branchID, forHTTPHeaderField: "X-Branch-ID") }
        let (data, rawResponse) = try await session.data(for: request)
        guard let http = rawResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.server(http.statusCode) }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum TokenVault {
    private static let service = "com.smarterp.mobile.session"

    static func store(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result = SecItemAdd(attributes as CFDictionary, nil)
        guard result == errSecSuccess else { throw APIError.unauthenticated }
    }

    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(query as CFDictionary)
    }
}
