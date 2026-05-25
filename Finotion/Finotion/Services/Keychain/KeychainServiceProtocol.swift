import Foundation

protocol KeychainServiceProtocol: Sendable {
    func save(token: String) throws
    func loadToken() -> String?
    func deleteToken()
}

enum KeychainError: Error {
    case encodingFailed
    case unexpectedStatus(OSStatus)
}
