import Foundation
import SwiftData

protocol MerchantAliasServiceProtocol: Sendable {
    func resolve(rawName: String) async -> String
    func register(rawName: String) async
}

@MainActor
final class MerchantAliasService: MerchantAliasServiceProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func resolve(rawName: String) async -> String {
        let lower = rawName.lowercased()
        let descriptor = FetchDescriptor<MerchantAlias>()
        let aliases = (try? context.fetch(descriptor)) ?? []
        return aliases.first(where: { $0.rawName.lowercased() == lower })?.alias ?? rawName
    }

    func register(rawName: String) async {
        let name = rawName
        let descriptor = FetchDescriptor<MerchantAlias>(
            predicate: #Predicate<MerchantAlias> { $0.rawName == name }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.seenAt = .now
        } else {
            context.insert(MerchantAlias(rawName: rawName, alias: nil, seenAt: .now))
        }
        try? context.save()
    }
}
