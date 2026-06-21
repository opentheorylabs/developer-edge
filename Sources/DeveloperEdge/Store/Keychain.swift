import Foundation
import Security
import Defaults

enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "com.opentheorylabs.developer-edge"

    static func read(_ account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8), !str.isEmpty
        else { return nil }
        return str
    }

    @discardableResult
    static func write(_ account: String, _ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    /// Read from Keychain; on miss, migrate from a legacy UserDefaults key.
    /// The legacy value is only cleared after a confirmed Keychain write.
    static func migratingRead(_ account: String, legacy key: Defaults.Key<String>) -> String {
        if let kc = read(account) { return kc }
        let old = Defaults[key]
        if !old.isEmpty, write(account, old) {
            Defaults[key] = ""
        }
        return old
    }

    static func delete(_ account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
