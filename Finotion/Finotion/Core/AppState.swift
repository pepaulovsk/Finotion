import Foundation
import Observation

enum AuthStatus: Equatable {
    case unknown
    case authenticated
    case unauthenticated
}

enum SyncStatus {
    case idle
    case syncing
    case failed(Error)
}

@Observable
final class AppState {
    var authStatus: AuthStatus = .unknown
    var fieldMapping: FieldMapping?
    var iCloudSyncStatus: SyncStatus = .idle
    var pendingIntent: ExpenseEntryIntent?

    private let keychainService: any KeychainServiceProtocol
    private let kvStoreService: any iCloudKVStoreServiceProtocol

    init(
        keychainService: any KeychainServiceProtocol = KeychainService(),
        kvStoreService: any iCloudKVStoreServiceProtocol = iCloudKVStoreService()
    ) {
        self.keychainService = keychainService
        self.kvStoreService = kvStoreService
    }

    func resolveAuthStatus() {
        let token = keychainService.loadToken()
        let mapping = kvStoreService.load()
        fieldMapping = mapping
        if token != nil, mapping != nil {
            authStatus = .authenticated
        } else {
            authStatus = .unauthenticated
        }
    }

    func reloadFieldMapping() {
        fieldMapping = kvStoreService.load()
    }

    func completeOnboarding(token: String, mapping: FieldMapping) throws {
        try keychainService.save(token: token)
        try kvStoreService.save(mapping)
        fieldMapping = mapping
        authStatus = .authenticated
    }

    func signOut() {
        keychainService.deleteToken()
        kvStoreService.clear()
        fieldMapping = nil
        authStatus = .unauthenticated
    }

    func updateFieldMapping(_ mapping: FieldMapping) throws {
        try kvStoreService.save(mapping)
        fieldMapping = mapping
    }
}
