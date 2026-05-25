import Foundation

protocol iCloudKVStoreServiceProtocol: Sendable {
    func save(_ mapping: FieldMapping) throws
    func load() -> FieldMapping?
    func clear()
}

// @unchecked Sendable because NSUbiquitousKeyValueStore is thread-safe in practice
// but does not formally conform to Sendable.
final class iCloudKVStoreService: iCloudKVStoreServiceProtocol, @unchecked Sendable {

    private let store = NSUbiquitousKeyValueStore.default
    private let key = "fieldMapping"

    func save(_ mapping: FieldMapping) throws {
        let data = try JSONEncoder().encode(mapping)
        store.set(data, forKey: key)
    }

    func load() -> FieldMapping? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FieldMapping.self, from: data)
    }

    func clear() {
        store.removeObject(forKey: key)
    }

    // Called on app foreground by AppState (task_05).
    func synchronize() {
        store.synchronize()
    }
}
