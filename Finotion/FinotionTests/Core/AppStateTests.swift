import XCTest
@testable import Finotion

@MainActor
final class AppStateTests: XCTestCase {

    private let sampleMapping = FieldMapping(
        databaseId: "db-1",
        nameField: "Name",
        amountField: "Amount",
        dateField: "Date"
    )

    // MARK: - AppState auth resolution

    func testAuthenticatedWhenTokenAndMappingPresent() throws {
        let keychain = MockKeychainService()
        try keychain.save(token: "token-abc")
        let kvStore = MockiCloudKVStoreService()
        try kvStore.save(sampleMapping)

        let state = AppState(keychainService: keychain, kvStoreService: kvStore)
        state.resolveAuthStatus()

        XCTAssertEqual(state.authStatus, .authenticated)
        XCTAssertEqual(state.fieldMapping, sampleMapping)
    }

    func testUnauthenticatedWhenNoToken() throws {
        let kvStore = MockiCloudKVStoreService()
        try kvStore.save(sampleMapping)

        let state = AppState(keychainService: MockKeychainService(), kvStoreService: kvStore)
        state.resolveAuthStatus()

        XCTAssertEqual(state.authStatus, .unauthenticated)
    }

    func testUnauthenticatedWhenTokenButNoMapping() throws {
        let keychain = MockKeychainService()
        try keychain.save(token: "token-abc")

        let state = AppState(keychainService: keychain, kvStoreService: MockiCloudKVStoreService())
        state.resolveAuthStatus()

        XCTAssertEqual(state.authStatus, .unauthenticated)
    }

    func testReloadFieldMappingUpdatesState() throws {
        let keychain = MockKeychainService()
        try keychain.save(token: "token-abc")
        let kvStore = MockiCloudKVStoreService()

        let state = AppState(keychainService: keychain, kvStoreService: kvStore)
        state.resolveAuthStatus()
        XCTAssertNil(state.fieldMapping)

        try kvStore.save(sampleMapping)
        state.reloadFieldMapping()
        XCTAssertEqual(state.fieldMapping, sampleMapping)
    }

    // MARK: - FeatureAccess

    func testFullAccessRecurringPaymentsIsTrue() {
        XCTAssertTrue(FullAccess().recurringPayments)
    }

    func testFullAccessMerchantAliasesIsTrue() {
        XCTAssertTrue(FullAccess().merchantAliases)
    }

    func testFullAccessNotificationCaptureIsFalse() {
        XCTAssertFalse(FullAccess().notificationCapture)
    }

    func testFullAccessIncomeTrackingIsFalse() {
        XCTAssertFalse(FullAccess().incomeTracking)
    }

    // MARK: - CategoryService cache

    func testCategoryServiceCachesOnSecondCall() async throws {
        let mock = MockNotionService(
            transactionsByDatabase: ["db-1": [
                Transaction(name: "Coffee", amount: 5, date: .now, category: "Food"),
                Transaction(name: "Taxi", amount: 15, date: .now, category: "Transport")
            ]]
        )
        let service = CategoryService(notionService: mock)

        let first = try await service.fetchCategories(databaseId: "db-1")
        XCTAssertEqual(first.sorted(), ["Food", "Transport"])

        mock.queryTransactionsError = .serverError(500)
        let second = try await service.fetchCategories(databaseId: "db-1")
        XCTAssertEqual(second.sorted(), ["Food", "Transport"])
    }

    func testCategoryServiceInvalidateTriggersFreshFetch() async throws {
        let mock = MockNotionService(
            transactionsByDatabase: ["db-1": [
                Transaction(name: "Coffee", amount: 5, date: .now, category: "Food")
            ]]
        )
        let service = CategoryService(notionService: mock)

        _ = try await service.fetchCategories(databaseId: "db-1")
        service.invalidate()

        mock.queryTransactionsError = .serverError(500)
        do {
            _ = try await service.fetchCategories(databaseId: "db-1")
            XCTFail("Expected error after invalidate")
        } catch {
            XCTAssertTrue(error is NotionError)
        }
    }

    func testAddCategoryAppendsToCache() async throws {
        let mock = MockNotionService(
            transactionsByDatabase: ["db-1": [
                Transaction(name: "Coffee", amount: 5, date: .now, category: "Food")
            ]]
        )
        let service = CategoryService(notionService: mock)

        let initial = try await service.fetchCategories(databaseId: "db-1")
        XCTAssertEqual(initial, ["Food"])

        try await service.addCategory("Pets", databaseId: "db-1", propertyId: "prop-1")

        let updated = try await service.fetchCategories(databaseId: "db-1")
        XCTAssertTrue(updated.contains("Pets"))
        XCTAssertTrue(updated.contains("Food"))
    }
}
