import Foundation
import Security

/// Guarda el JWT en el Keychain (equivalente nativo al `localStorage` de la web,
/// pero cifrado por el sistema y accesible solo con el dispositivo desbloqueado).
enum TokenStore {

    private static let service = "com.finanz.app"
    private static let account = "jwt_token"

    static var token: String? {
        get { read() }
        set {
            if let newValue, !newValue.isEmpty {
                save(newValue)
            } else {
                delete()
            }
        }
    }

    // MARK: - Keychain

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func save(_ value: String) {
        let data = Data(value.utf8)
        let query = baseQuery()

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { current, _ in current }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
