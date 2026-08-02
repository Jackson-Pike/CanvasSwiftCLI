import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.byuh.CanvasApp"
    private static let legacyAccount = "canvas_token"
    private static let legacyHost = "byuh.instructure.com"
    private static let label = "Canvas Grades – API Token"
    private static let itemDescription = "Canvas LMS API token for reading grades"

    // In DEBUG builds the app is re-signed on every rebuild, which triggers a
    // Keychain access prompt each time. UserDefaults sidesteps that entirely.
    private static let legacyDevDefaultsKey = "dev_canvas_token"

    private static func account(for host: String) -> String {
        "canvas_token.\(host)"
    }

    private static func devDefaultsKey(for host: String) -> String {
        "dev_canvas_token.\(host)"
    }

    static func save(token: String, host: String) {
#if DEBUG
        UserDefaults.standard.set(token, forKey: devDefaultsKey(for: host))
#else
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: host)
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrLabel: label,
            kSecAttrDescription: itemDescription
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addAttrs = query
            addAttrs[kSecValueData] = data
            addAttrs[kSecAttrLabel] = label
            addAttrs[kSecAttrDescription] = itemDescription
            SecItemAdd(addAttrs as CFDictionary, nil)
        } else if status != errSecSuccess {
            print("[KeychainHelper] SecItemUpdate failed with status: \(status)")
        }
#endif
    }

    static func load(host: String) -> String? {
#if DEBUG
        if let token = UserDefaults.standard.string(forKey: devDefaultsKey(for: host)) {
            return token
        }
        if host == legacyHost, let legacyToken = UserDefaults.standard.string(forKey: legacyDevDefaultsKey) {
            UserDefaults.standard.set(legacyToken, forKey: devDefaultsKey(for: host))
            UserDefaults.standard.removeObject(forKey: legacyDevDefaultsKey)
            return legacyToken
        }
        return nil
#else
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: host),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        if host == legacyHost {
            let legacyQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: legacyAccount,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ]
            var legacyResult: AnyObject?
            if SecItemCopyMatching(legacyQuery as CFDictionary, &legacyResult) == errSecSuccess,
               let legacyData = legacyResult as? Data,
               let legacyToken = String(data: legacyData, encoding: .utf8) {
                save(token: legacyToken, host: host)
                let deleteQuery: [CFString: Any] = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccount: legacyAccount
                ]
                SecItemDelete(deleteQuery as CFDictionary)
                return legacyToken
            }
        }
        return nil
#endif
    }

    static func delete(host: String) {
#if DEBUG
        UserDefaults.standard.removeObject(forKey: devDefaultsKey(for: host))
#else
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: host)
        ]
        SecItemDelete(query as CFDictionary)
#endif
    }
}
