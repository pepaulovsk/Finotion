import SwiftData
import XCTest
@testable import Finotion

@MainActor
final class ExpenseEntryViewModelTests: XCTestCase {

    private var mockNotion: MockNotionService!
    private var mockSync: MockSyncService!
    private var mockAlias: MockMerchantAliasService!
    private var categoryService: CategoryService!
    private let mapping = FieldMapping(databaseId: "db-1", nameField: "Name", amountField: "Amount", dateField: "Date")

    override func setUp() {
        super.setUp()
        mockNotion = MockNotionService()
        mockSync = MockSyncService()
        mockAlias = MockMerchantAliasService()
        categoryService = CategoryService(notionService: mockNotion)
    }

    private func makeVM(intent: ExpenseEntryIntent? = nil) -> ExpenseEntryViewModel {
        ExpenseEntryViewModel(
            notionService: mockNotion,
            categoryService: categoryService,
            aliasService: mockAlias,
            syncService: mockSync,
            fieldMapping: mapping,
            intent: intent
        )
    }

    // MARK: - Validation

    func testIsInvalidWithNoNameAndNoAmount() {
        let vm = makeVM()
        XCTAssertFalse(vm.isValid)
    }

    func testIsInvalidWithNameButNoAmount() {
        let vm = makeVM()
        vm.name = "Padaria"
        XCTAssertFalse(vm.isValid)
    }

    func testIsValidWithNameAndPositiveAmount() {
        let vm = makeVM()
        vm.name = "Padaria"
        vm.amountText = "15.50"
        XCTAssertTrue(vm.isValid)
    }

    func testIsInvalidWhenAmountIsZero() {
        let vm = makeVM()
        vm.name = "Padaria"
        vm.amountText = "0"
        XCTAssertFalse(vm.isValid)
    }

    // MARK: - Intent pre-fill

    func testIntentPreFillsNameAndAmount() {
        let intent = ExpenseEntryIntent(merchant: "Padaria", amount: 12.0)
        let vm = makeVM(intent: intent)
        XCTAssertEqual(vm.name, "Padaria")
        XCTAssertEqual(vm.amountText, "12.0")
    }

    func testIntentPreFillsPaymentMethod() {
        let intent = ExpenseEntryIntent(merchant: nil, amount: nil, paymentMethod: "Credit")
        let vm = makeVM(intent: intent)
        XCTAssertEqual(vm.paymentMethod, "Credit")
    }

    // MARK: - Save — success path

    func testSaveCallsCreateTransactionOnceWithCorrectDatabaseId() async throws {
        let vm = makeVM()
        vm.name = "Padaria"
        vm.amountText = "10.0"

        vm.save()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 1)
    }

    func testSaveDismissesImmediately() {
        let vm = makeVM()
        vm.name = "Padaria"
        vm.amountText = "10.0"
        vm.save()
        XCTAssertTrue(vm.shouldDismiss)
    }

    // MARK: - Save — failure path (enqueue)

    func testSaveEnqueuesEntryWhenNotionFails() async throws {
        mockNotion.createTransactionError = .serverError(500)
        let vm = makeVM()
        vm.name = "Padaria"
        vm.amountText = "10.0"

        vm.save()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockSync.enqueuedEntries.count, 1)
        let entry = try XCTUnwrap(mockSync.enqueuedEntries.first)
        let payload = try JSONDecoder().decode(PendingTransactionPayload.self, from: entry.transactionData)
        XCTAssertEqual(payload.transaction.name, "Padaria")
        XCTAssertEqual(payload.databaseId, "db-1")
    }

    // MARK: - MerchantAliasService unit tests

    func testMockAliasResolveReturnsAlias() async {
        let service = MockMerchantAliasService(aliases: ["RENATA PASCOLLI SOUSA": "Padaria da Renata"])
        let result = await service.resolve(rawName: "RENATA PASCOLLI SOUSA")
        XCTAssertEqual(result, "Padaria da Renata")
    }

    func testMockAliasResolveReturnRawNameWhenNoAlias() async {
        let service = MockMerchantAliasService()
        let result = await service.resolve(rawName: "UNKNOWN STORE")
        XCTAssertEqual(result, "UNKNOWN STORE")
    }

    func testMerchantAliasServiceRegistersNewRecord() async throws {
        let container = try DataContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let service = MerchantAliasService(context: context)

        await service.register(rawName: "NEW STORE")

        let descriptor = FetchDescriptor<MerchantAlias>()
        let aliases = try context.fetch(descriptor)
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases.first?.rawName, "NEW STORE")
        XCTAssertNil(aliases.first?.alias)
    }

    func testMerchantAliasServiceResolvesExistingAlias() async throws {
        let container = try DataContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(MerchantAlias(rawName: "RENATA PASCOLLI SOUSA", alias: "Padaria da Renata"))
        try context.save()

        let service = MerchantAliasService(context: context)
        let result = await service.resolve(rawName: "RENATA PASCOLLI SOUSA")
        XCTAssertEqual(result, "Padaria da Renata")
    }

    func testMerchantAliasServiceResolvesCaseInsensitive() async throws {
        let container = try DataContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(MerchantAlias(rawName: "renata pascolli sousa", alias: "Padaria da Renata"))
        try context.save()

        let service = MerchantAliasService(context: context)
        let result = await service.resolve(rawName: "RENATA PASCOLLI SOUSA")
        XCTAssertEqual(result, "Padaria da Renata")
    }
}
