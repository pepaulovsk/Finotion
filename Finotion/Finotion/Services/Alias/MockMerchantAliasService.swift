import Foundation

final class MockMerchantAliasService: MerchantAliasServiceProtocol, @unchecked Sendable {
    private var aliases: [String: String]
    private(set) var registeredNames: [String] = []

    init(aliases: [String: String] = [:]) {
        self.aliases = aliases
    }

    func resolve(rawName: String) async -> String {
        let lower = rawName.lowercased()
        let match = aliases.first(where: { $0.key.lowercased() == lower })
        return match?.value ?? rawName
    }

    func register(rawName: String) async {
        registeredNames.append(rawName)
    }
}
