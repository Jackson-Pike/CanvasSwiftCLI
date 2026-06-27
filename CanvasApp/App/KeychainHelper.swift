import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.byuh.CanvasApp"
    private static let account = "canvas_token"
    private static let label = "Canvas Grades – API Token"
    private static let itemDescription = "Canvas LMS API token for reading grades"

    static func save(token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
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
        }
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
