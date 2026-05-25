import Foundation

final class MockiCloudKVStoreService: iCloudKVStoreServiceProtocol, @unchecked Sendable {

    private var store: [String: Data] = [:]
    private let key = "fieldMapping"

    func save(_ mapping: FieldMapping) throws {
        store[key] = try JSONEncoder().encode(mapping)
    }

    func load() -> FieldMapping? {
        guard let data = store[key] else { return nil }
        return try? JSONDecoder().decode(FieldMapping.self, from: data)
    }

    func clear() { store[key] = nil }

    func setCorruptedData() { store[key] = "not valid json".data(using: .utf8) }
}
