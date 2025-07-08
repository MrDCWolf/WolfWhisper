import Foundation
import Security

final class KeychainService: Sendable {
    static let shared = KeychainService()
    private let service = "com.wolfwhisper.apikey"

    private init() {}

    func saveAPIKey(_ apiKey: String, for account: String) async -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }
        
        return await Task {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            // Delete any existing item
            SecItemDelete(query as CFDictionary)
            
            let attributes: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]
            
            let status = SecItemAdd(attributes as CFDictionary, nil)
            return status == errSecSuccess
        }.value
    }

    func loadAPIKey(for account: String) async -> String? {
        await Task {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var dataTypeRef: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
            
            guard status == errSecSuccess,
                  let data = dataTypeRef as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                return nil
            }
            return apiKey
        }.value
    }

    func deleteAPIKey(for account: String) async {
        await Task {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }.value
    }
} 