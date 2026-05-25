import XCTest
@testable import Finotion

final class NotionServiceTests: XCTestCase {

    private var mock: MockNotionService!
    private let dbId = "db-test"

    override func setUp() {
        super.setUp()
        mock = MockNotionService(
            databases: [NotionDatabase(id: dbId, title: "Test DB")],
            propertiesByDatabase: [dbId: .templateProperties],
            transactionsByDatabase: [dbId: []]
        )
    }

    override func tearDown() {
        mock = nil
        super.tearDown()
    }

    // MARK: - fetchDatabases

    func testFetchDatabasesReturnsSeededDatabases() async throws {
        let dbs = try await mock.fetchDatabases()
        XCTAssertEqual(dbs.count, 1)
        XCTAssertEqual(dbs.first?.title, "Test DB")
    }

    func testFetchDatabasesEmptyForFreshMock() async throws {
        let dbs = try await MockNotionService().fetchDatabases()
        XCTAssertTrue(dbs.isEmpty)
    }

    func testFetchDatabasesThrowsInjectedError() async {
        mock.fetchDatabasesError = .unauthorized
        do {
            _ = try await mock.fetchDatabases()
            XCTFail("Expected unauthorized error")
        } catch let err as NotionError {
            XCTAssertEqual(err, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - createTransaction / queryTransactions

    func testCreateTransactionAddsToStateAndIsRetrievable() async throws {
        let tx = Transaction(name: "Mercado", amount: 50.0, category: "Alimentação")
        let returnedId = try await mock.createTransaction(tx, databaseId: dbId)

        XCTAssertEqual(returnedId, tx.id.uuidString)

        let stored = try await mock.queryTransactions(databaseId: dbId, filter: nil)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, tx.id)
        XCTAssertEqual(stored.first?.name, "Mercado")
    }

    func testCreateTransactionThrowsServerError500() async {
        mock.createTransactionError = .serverError(500)
        let tx = Transaction(name: "Fail", amount: 1.0)
        do {
            _ = try await mock.createTransaction(tx, databaseId: dbId)
            XCTFail("Expected serverError(500)")
        } catch let err as NotionError {
            XCTAssertEqual(err, .serverError(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testQueryTransactionsReturnsEmptyWhenNoTransactions() async throws {
        let results = try await mock.queryTransactions(databaseId: dbId, filter: nil)
        XCTAssertTrue(results.isEmpty)
    }

    func testQueryTransactionsFiltersByStartDate() async throws {
        _ = try await mock.createTransaction(
            Transaction(name: "Recent", amount: 10.0, date: .now), databaseId: dbId
        )
        _ = try await mock.createTransaction(
            Transaction(name: "Old", amount: 20.0, date: Date(timeIntervalSinceNow: -604_800)),
            databaseId: dbId
        )
        let results = try await mock.queryTransactions(
            databaseId: dbId,
            filter: NotionFilter(startDate: Date(timeIntervalSinceNow: -86_400))
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Recent")
    }

    func testQueryTransactionsFiltersByCategory() async throws {
        _ = try await mock.createTransaction(
            Transaction(name: "Uber", amount: 23.0, category: "Transporte"), databaseId: dbId
        )
        _ = try await mock.createTransaction(
            Transaction(name: "Mercado", amount: 80.0, category: "Alimentação"), databaseId: dbId
        )
        let results = try await mock.queryTransactions(
            databaseId: dbId,
            filter: NotionFilter(category: "Transporte")
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Uber")
    }

    // MARK: - fetchDatabaseProperties

    func testFetchDatabasePropertiesReturnsSeededProperties() async throws {
        let props = try await mock.fetchDatabaseProperties(dbId)
        XCTAssertFalse(props.isEmpty)
        XCTAssertTrue(props.contains(where: { $0.type == "title" }))
        XCTAssertTrue(props.contains(where: { $0.name == "Valor" }))
    }

    func testFetchDatabasePropertiesUnknownIdThrows404() async {
        do {
            _ = try await mock.fetchDatabaseProperties("unknown-id")
            XCTFail("Expected serverError(404)")
        } catch let err as NotionError {
            XCTAssertEqual(err, .serverError(404))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchDatabasePropertiesThrowsInjectedError() async {
        mock.fetchDatabasePropertiesError = .rateLimited
        do {
            _ = try await mock.fetchDatabaseProperties(dbId)
            XCTFail("Expected rateLimited error")
        } catch let err as NotionError {
            XCTAssertEqual(err, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - NotionError equatability

    func testNotionErrorEquatableCases() {
        XCTAssertEqual(NotionError.unauthorized, .unauthorized)
        XCTAssertEqual(NotionError.rateLimited, .rateLimited)
        XCTAssertEqual(NotionError.serverError(500), .serverError(500))
        XCTAssertNotEqual(NotionError.serverError(500), .serverError(404))
        XCTAssertNotEqual(NotionError.unauthorized, .rateLimited)
        let urlErr = URLError(.notConnectedToInternet)
        XCTAssertEqual(NotionError.networkError(urlErr), .networkError(urlErr))
        let decodeErr = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        XCTAssertEqual(NotionError.decodingError(decodeErr), .decodingError(decodeErr))
    }

    // MARK: - Transaction Codable

    func testTransactionCodableRoundTripAllFields() throws {
        let original = Transaction(
            name: "Restaurante",
            amount: 98.50,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            refDate: Date(timeIntervalSince1970: 1_700_100_000),
            category: "Alimentação",
            paymentMethod: "Crédito",
            description: "Almoço",
            type: .expense
        )
        let decoded = try JSONDecoder().decode(
            Transaction.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.amount, original.amount)
        XCTAssertEqual(decoded.date, original.date)
        XCTAssertEqual(decoded.refDate, original.refDate)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.paymentMethod, original.paymentMethod)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.type, original.type)
    }

    func testTransactionCodableNilOptionalsPreserved() throws {
        let tx = Transaction(name: "Simples", amount: 10.0)
        let decoded = try JSONDecoder().decode(Transaction.self, from: JSONEncoder().encode(tx))
        XCTAssertNil(decoded.refDate)
        XCTAssertNil(decoded.category)
        XCTAssertNil(decoded.paymentMethod)
        XCTAssertNil(decoded.description)
    }

    // MARK: - createDatabase

    func testCreateDatabaseAddsToStateAndReturnsDatabase() async throws {
        let db = try await mock.createDatabase(parentPageId: "parent-page-id")
        XCTAssertFalse(db.id.isEmpty)
        XCTAssertFalse(db.title.isEmpty)
        let dbs = try await mock.fetchDatabases()
        XCTAssertTrue(dbs.contains(where: { $0.id == db.id }))
    }

    func testCreateDatabaseThrowsInjectedError() async {
        mock.createDatabaseError = .serverError(503)
        do {
            _ = try await mock.createDatabase(parentPageId: "parent-page-id")
            XCTFail("Expected serverError(503)")
        } catch let err as NotionError {
            XCTAssertEqual(err, .serverError(503))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - addCategoryOption

    func testAddCategoryOptionSucceedsWithoutThrowing() async throws {
        try await mock.addCategoryOption("Lazer", databaseId: dbId, propertyId: "prop-category")
    }

    func testAddCategoryOptionThrowsInjectedError() async {
        mock.addCategoryOptionError = .unauthorized
        do {
            try await mock.addCategoryOption("Lazer", databaseId: dbId, propertyId: "prop-category")
            XCTFail("Expected unauthorized error")
        } catch let err as NotionError {
            XCTAssertEqual(err, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Preview factory

    func testPreviewInstanceConformsToNotionService() {
        let service: any NotionService = MockNotionService.preview
        XCTAssertNotNil(service)
    }
}
