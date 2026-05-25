import XCTest
import SwiftData
@testable import Finotion

@MainActor
final class SwiftDataTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try DataContainer.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - RecurringPayment CRUD

    func testInsertAndFetchRecurringPayment() throws {
        let payment = RecurringPayment(name: "Netflix", amount: 55.90, dueDay: 5, categoryName: "Assinaturas")
        context.insert(payment)
        try context.save()

        let results = try context.fetch(FetchDescriptor<RecurringPayment>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Netflix")
        XCTAssertEqual(results.first?.amount, 55.90)
        XCTAssertTrue(results.first?.isActive == true)
    }

    func testUpdateRecurringPayment() throws {
        let payment = RecurringPayment(name: "Spotify", amount: 29.90, dueDay: 10, categoryName: "Assinaturas")
        context.insert(payment)
        try context.save()

        payment.amount = 34.90
        try context.save()

        let results = try context.fetch(FetchDescriptor<RecurringPayment>())
        XCTAssertEqual(results.first?.amount, 34.90)
    }

    func testDeleteRecurringPayment() throws {
        let payment = RecurringPayment(name: "Spotify", amount: 29.90, dueDay: 10, categoryName: "Assinaturas")
        context.insert(payment)
        try context.save()
        context.delete(payment)
        try context.save()

        let results = try context.fetch(FetchDescriptor<RecurringPayment>())
        XCTAssertTrue(results.isEmpty)
    }

    func testRecurringPaymentIdUniquenessUpserts() throws {
        let id = UUID()
        context.insert(RecurringPayment(id: id, name: "Netflix", amount: 55.90, dueDay: 5, categoryName: "Assinaturas"))
        try context.save()

        // SwiftData upserts on unique constraint: second insert merges into first
        context.insert(RecurringPayment(id: id, name: "Spotify", amount: 29.90, dueDay: 10, categoryName: "Assinaturas"))
        try context.save()

        let results = try context.fetch(FetchDescriptor<RecurringPayment>())
        XCTAssertEqual(results.count, 1, "Unique id: only one RecurringPayment per id")
    }

    // MARK: - MerchantAlias uniqueness

    func testMerchantAliasRawNameUniquenessUpserts() throws {
        context.insert(MerchantAlias(rawName: "Padaria Sousa"))
        try context.save()

        context.insert(MerchantAlias(rawName: "Padaria Sousa", alias: "Padaria"))
        try context.save()

        let results = try context.fetch(FetchDescriptor<MerchantAlias>())
        XCTAssertEqual(results.count, 1, "Unique rawName: only one MerchantAlias per rawName")
    }

    // MARK: - PendingEntry status transitions

    func testPendingEntryStatusTransition() throws {
        let data = (try? JSONEncoder().encode(Transaction(name: "Test", amount: 10.0))) ?? Data()
        let entry = PendingEntry(transactionData: data, status: "pending")
        context.insert(entry)
        try context.save()

        entry.status = "synced"
        try context.save()

        let results = try context.fetch(FetchDescriptor<PendingEntry>())
        XCTAssertEqual(results.first?.status, "synced")
    }

    // MARK: - BudgetGoal

    func testBudgetGoalDistinctByYearMonth() throws {
        context.insert(BudgetGoal(categoryName: "Alimentação", yearMonth: "2026-05", limitAmount: 800))
        context.insert(BudgetGoal(categoryName: "Alimentação", yearMonth: "2026-06", limitAmount: 900))
        try context.save()

        let results = try context.fetch(FetchDescriptor<BudgetGoal>())
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - BudgetGoalService.autoCarry

    func testAutoCarryCopiesThreeGoalsToEmptyMonth() throws {
        let sourceGoals = [
            BudgetGoal(categoryName: "Alimentação", yearMonth: "2026-04", limitAmount: 800),
            BudgetGoal(categoryName: "Transporte", yearMonth: "2026-04", limitAmount: 300),
            BudgetGoal(categoryName: "Lazer", yearMonth: "2026-04", limitAmount: 200)
        ]
        sourceGoals.forEach { context.insert($0) }
        try context.save()

        try BudgetGoalService.autoCarry(from: "2026-04", to: "2026-05", context: context)

        let results = try context.fetch(FetchDescriptor<BudgetGoal>(
            predicate: #Predicate { $0.yearMonth == "2026-05" }
        ))
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains(where: { $0.categoryName == "Alimentação" && $0.limitAmount == 800 }))
        XCTAssertTrue(results.contains(where: { $0.categoryName == "Transporte" && $0.limitAmount == 300 }))
    }

    func testAutoCarryDoesNotOverwriteExistingGoals() throws {
        context.insert(BudgetGoal(categoryName: "Alimentação", yearMonth: "2026-04", limitAmount: 800))
        context.insert(BudgetGoal(categoryName: "Alimentação", yearMonth: "2026-05", limitAmount: 1000))
        try context.save()

        try BudgetGoalService.autoCarry(from: "2026-04", to: "2026-05", context: context)

        let results = try context.fetch(FetchDescriptor<BudgetGoal>(
            predicate: #Predicate { $0.yearMonth == "2026-05" }
        ))
        XCTAssertEqual(results.count, 1, "Existing goals must not be overwritten")
        XCTAssertEqual(results.first?.limitAmount, 1000)
    }

    // MARK: - DataContainer

    func testMakeContainerInMemorySucceeds() throws {
        XCTAssertNoThrow(try DataContainer.makeContainer(inMemory: true))
    }

    func testMakeContainerProductionInitializesWithoutCrash() {
        // CloudKit sync is async — verify no crash on init.
        // May silently fail to sync in environments without CloudKit entitlements.
        _ = try? DataContainer.makeContainer(inMemory: false)
    }
}
