import Foundation
import Observation

@Observable
final class CategoryService {
    private var cache: [String: [String]] = [:]
    private let notionService: any NotionService

    init(notionService: any NotionService) {
        self.notionService = notionService
    }

    func fetchCategories(databaseId: String) async throws -> [String] {
        if let cached = cache[databaseId] {
            return cached
        }
        let transactions = try await notionService.queryTransactions(databaseId: databaseId, filter: nil)
        let categories = Array(Set(transactions.compactMap(\.category))).sorted()
        cache[databaseId] = categories
        return categories
    }

    func addCategory(_ name: String, databaseId: String, propertyId: String) async throws {
        try await notionService.addCategoryOption(name, databaseId: databaseId, propertyId: propertyId)
        var existing = cache[databaseId] ?? []
        if !existing.contains(name) {
            existing.append(name)
            cache[databaseId] = existing
        }
    }

    func invalidate() {
        cache.removeAll()
    }
}
