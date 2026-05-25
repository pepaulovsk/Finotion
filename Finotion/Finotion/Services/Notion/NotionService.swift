import Foundation

// MARK: - Domain Types

enum TransactionType: String, Codable, Sendable {
    case expense
    case income
}

struct Transaction: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var amount: Double
    var date: Date
    var refDate: Date?
    var category: String?
    var paymentMethod: String?
    var description: String?
    var type: TransactionType

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        date: Date = .now,
        refDate: Date? = nil,
        category: String? = nil,
        paymentMethod: String? = nil,
        description: String? = nil,
        type: TransactionType = .expense
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.date = date
        self.refDate = refDate
        self.category = category
        self.paymentMethod = paymentMethod
        self.description = description
        self.type = type
    }
}

struct NotionDatabase: Codable, Identifiable, Sendable {
    let id: String
    var title: String
    var url: String?
}

struct NotionProperty: Codable, Identifiable, Sendable {
    let id: String
    var name: String
    var type: String
}

struct NotionFilter: Codable, Sendable {
    var startDate: Date?
    var endDate: Date?
    var category: String?
}

// MARK: - Error

enum NotionError: Error, Sendable {
    case unauthorized
    case rateLimited
    case serverError(Int)
    case networkError(URLError)
    case decodingError(Error)
}

extension NotionError: Equatable {
    static func == (lhs: NotionError, rhs: NotionError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized): return true
        case (.rateLimited, .rateLimited): return true
        case let (.serverError(l), .serverError(r)): return l == r
        case let (.networkError(l), .networkError(r)): return l.code == r.code
        case (.decodingError, .decodingError): return true
        default: return false
        }
    }
}

// MARK: - Protocol

protocol NotionService: Sendable {
    func fetchDatabases() async throws -> [NotionDatabase]
    func fetchDatabaseProperties(_ id: String) async throws -> [NotionProperty]
    func createDatabase(parentPageId: String) async throws -> NotionDatabase
    func queryTransactions(databaseId: String, filter: NotionFilter?) async throws -> [Transaction]
    func createTransaction(_ tx: Transaction, databaseId: String) async throws -> String
    func addCategoryOption(_ name: String, databaseId: String, propertyId: String) async throws
}
