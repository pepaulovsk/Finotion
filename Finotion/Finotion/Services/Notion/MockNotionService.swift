import Foundation

// MockNotionService is @unchecked Sendable because unit tests run on a single
// thread and the class is never shared across concurrent contexts.
final class MockNotionService: NotionService, @unchecked Sendable {

    // MARK: - State

    private var databases: [NotionDatabase]
    private var propertiesByDatabase: [String: [NotionProperty]]
    private var transactionsByDatabase: [String: [Transaction]]

    // MARK: - Failure injection

    var fetchDatabasesError: NotionError?
    var fetchDatabasePropertiesError: NotionError?
    var createDatabaseError: NotionError?
    var queryTransactionsError: NotionError?
    var createTransactionError: NotionError?
    var addCategoryOptionError: NotionError?
    private(set) var queryTransactionsCallCount = 0

    // MARK: - Init

    init(
        databases: [NotionDatabase] = [],
        propertiesByDatabase: [String: [NotionProperty]] = [:],
        transactionsByDatabase: [String: [Transaction]] = [:]
    ) {
        self.databases = databases
        self.propertiesByDatabase = propertiesByDatabase
        self.transactionsByDatabase = transactionsByDatabase
    }

    // MARK: - NotionService

    func fetchDatabases() async throws -> [NotionDatabase] {
        if let error = fetchDatabasesError { throw error }
        return databases
    }

    func fetchDatabaseProperties(_ id: String) async throws -> [NotionProperty] {
        if let error = fetchDatabasePropertiesError { throw error }
        guard let props = propertiesByDatabase[id] else { throw NotionError.serverError(404) }
        return props
    }

    func createDatabase(parentPageId: String) async throws -> NotionDatabase {
        if let error = createDatabaseError { throw error }
        let db = NotionDatabase(id: UUID().uuidString, title: "Finotion Finance")
        databases.append(db)
        propertiesByDatabase[db.id] = .templateProperties
        return db
    }

    func queryTransactions(databaseId: String, filter: NotionFilter?) async throws -> [Transaction] {
        queryTransactionsCallCount += 1
        if let error = queryTransactionsError { throw error }
        var results = transactionsByDatabase[databaseId] ?? []
        if let filter {
            if let start = filter.startDate { results = results.filter { $0.date >= start } }
            if let end = filter.endDate { results = results.filter { $0.date <= end } }
            if let cat = filter.category { results = results.filter { $0.category == cat } }
            if let pid = filter.pendingId { results = results.filter { $0.description?.contains(pid) == true } }
            if let key = filter.recurringKey { results = results.filter { $0.description?.contains(key) == true } }
        }
        return results.sorted { $0.date > $1.date }
    }

    func createTransaction(_ tx: Transaction, databaseId: String) async throws -> String {
        if let error = createTransactionError { throw error }
        transactionsByDatabase[databaseId, default: []].append(tx)
        return tx.id.uuidString
    }

    func addCategoryOption(_ name: String, databaseId: String, propertyId: String) async throws {
        if let error = addCategoryOptionError { throw error }
    }

    // MARK: - Test helpers

    func storedTransactions(in databaseId: String) -> [Transaction] {
        transactionsByDatabase[databaseId] ?? []
    }
}

// MARK: - Preview factory

extension MockNotionService {
    static var preview: MockNotionService {
        MockNotionService(
            databases: [
                NotionDatabase(id: "db-preview", title: "💰 Finanças Pessoais"),
                NotionDatabase(id: "db-preview-2", title: "📊 Gastos 2026")
            ],
            propertiesByDatabase: ["db-preview": .templateProperties],
            transactionsByDatabase: ["db-preview": .samples]
        )
    }
}

// MARK: - Sample data

extension Array where Element == NotionProperty {
    static var templateProperties: [NotionProperty] {
        [
            NotionProperty(id: "prop-name", name: "Nome", type: "title"),
            NotionProperty(id: "prop-amount", name: "Valor", type: "number"),
            NotionProperty(id: "prop-date", name: "Data", type: "date"),
            NotionProperty(id: "prop-category", name: "Categoria", type: "select"),
            NotionProperty(id: "prop-method", name: "Método", type: "select"),
            NotionProperty(id: "prop-type", name: "Tipo", type: "select"),
            NotionProperty(id: "prop-refdate", name: "Data Referência", type: "date")
        ]
    }
}

extension Array where Element == Transaction {
    static var samples: [Transaction] {
        [
            Transaction(name: "Supermercado", amount: 187.50,
                        date: .now,
                        category: "Alimentação", paymentMethod: "Débito"),
            Transaction(name: "Netflix", amount: 55.90,
                        date: Date(timeIntervalSinceNow: -172_800),
                        category: "Assinaturas", paymentMethod: "Crédito"),
            Transaction(name: "Farmácia", amount: 42.00,
                        date: Date(timeIntervalSinceNow: -259_200),
                        category: "Saúde", paymentMethod: "Débito"),
            Transaction(name: "Restaurante", amount: 98.00,
                        date: Date(timeIntervalSinceNow: -432_000),
                        category: "Alimentação", paymentMethod: "Crédito"),
            Transaction(name: "Uber", amount: 23.40,
                        date: Date(timeIntervalSinceNow: -518_400),
                        category: "Transporte", paymentMethod: "Crédito")
        ]
    }
}
