import Foundation
import Security

public enum KeychainStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidData
}

public struct KeychainStore {
    public static let defaultService = "Fluenta.OpenAI"
    public static let defaultAccount = "apiKey"

    private let service: String
    private let account: String

    public init(
        service: String = KeychainStore.defaultService,
        account: String = KeychainStore.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    public func saveAPIKey(_ apiKey: String) throws {
        let query = baseQuery()
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = Data(apiKey.utf8)

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }

        guard let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidData
        }

        return apiKey
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
