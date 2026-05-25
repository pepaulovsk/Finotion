import Foundation

final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {

    private var token: String?
    var shouldThrowOnSave = false

    func save(token: String) throws {
        if shouldThrowOnSave { throw KeychainError.unexpectedStatus(-1) }
        self.token = token
    }

    func loadToken() -> String? { token }

    func deleteToken() { token = nil }
}
