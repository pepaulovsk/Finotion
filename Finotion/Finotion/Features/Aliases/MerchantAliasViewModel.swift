import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class MerchantAliasViewModel {
    private(set) var unnamed: [MerchantAlias] = []
    private(set) var named: [MerchantAlias] = []
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        fetchAll()
    }

    func fetchAll() {
        let all = (try? context.fetch(FetchDescriptor<MerchantAlias>())) ?? []
        unnamed = all.filter { $0.alias == nil }.sorted { $0.seenAt > $1.seenAt }
        named = all.filter { $0.alias != nil }.sorted { ($0.alias ?? "") < ($1.alias ?? "") }
    }

    func setAlias(_ alias: String, for rawName: String) {
        let normalized = rawName.lowercased()
        let all = (try? context.fetch(FetchDescriptor<MerchantAlias>())) ?? []
        guard let record = all.first(where: { $0.rawName.lowercased() == normalized }) else { return }
        record.alias = alias
        try? context.save()
        fetchAll()
    }

    func clearAlias(for rawName: String) {
        let normalized = rawName.lowercased()
        let all = (try? context.fetch(FetchDescriptor<MerchantAlias>())) ?? []
        guard let record = all.first(where: { $0.rawName.lowercased() == normalized }) else { return }
        record.alias = nil
        try? context.save()
        fetchAll()
    }
}
