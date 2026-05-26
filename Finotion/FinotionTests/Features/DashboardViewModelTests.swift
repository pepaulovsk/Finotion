import Foundation
import SwiftData
import XCTest
@testable import Finotion

@MainActor
final class DashboardViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var mockNotion: MockNotionService!
    private let mapping = FieldMapping(databaseId: "db-1", nameField: "Name", amountField: "Amount", dateField: "Date")

    override func setUp() async throws {
        try await super.setUp()
        container = try DataContainer.makeContainer(inMemory: true)
        mockNotion = MockNotionService()
    }

    // MARK: - Helpers

    private func makeViewModel() -> DashboardViewModel {
        DashboardViewModel(
            notionService: mockNotion,
            categoryService: CategoryService(notionService: mockNotion),
            container: container,
            fieldMapping: mapping
        )
    }

    private func insert<T: PersistentModel>(_ model: T) {
        let context = ModelContext(container)
        context.insert(model)
        try? context.save()
    }

    private func yearMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func makeCurrentMonthDate(day: Int = 1) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: .now)
        components.day = day
        return calendar.date(from: components) ?? .now
    }

    // MARK: - currentMonthTotal

    func testCurrentMonthTotalIsCorrectSum() async throws {
        let date = makeCurrentMonthDate()
        mockNotion = MockNotionService(transactionsByDatabase: ["db-1": [
            Transaction(name: "A", amount: 100, date: date),
            Transaction(name: "B", amount: 50, date: date),
            Transaction(name: "C", amount: 25, date: date),
            Transaction(name: "D", amount: 75, date: date),
            Transaction(name: "E", amount: 10, date: date)
        ]])

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.currentMonthTotal, 260, accuracy: 0.01)
    }

    // MARK: - categoryTotals

    func testCategoryTotalsAggregatedByCategory() async throws {
        let date = makeCurrentMonthDate()
        mockNotion = MockNotionService(transactionsByDatabase: ["db-1": [
            Transaction(name: "A", amount: 30, date: date, category: "Food"),
            Transaction(name: "B", amount: 20, date: date, category: "Food"),
            Transaction(name: "C", amount: 10, date: date, category: "Food"),
            Transaction(name: "D", amount: 40, date: date, category: "Transport"),
            Transaction(name: "E", amount: 15, date: date, category: "Transport")
        ]])

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.categoryTotals.count, 2)
        let food = try XCTUnwrap(vm.categoryTotals.first(where: { $0.category == "Food" }))
        let transport = try XCTUnwrap(vm.categoryTotals.first(where: { $0.category == "Transport" }))
        XCTAssertEqual(food.spent, 60, accuracy: 0.01)
        XCTAssertEqual(transport.spent, 55, accuracy: 0.01)
    }

    func testBudgetGoalLimitAppearsInCategoryTotals() async throws {
        let date = makeCurrentMonthDate()
        let currentMonth = yearMonthString(from: .now)
        mockNotion = MockNotionService(transactionsByDatabase: ["db-1": [
            Transaction(name: "Pizza", amount: 80, date: date, category: "Food")
        ]])
        insert(BudgetGoal(categoryName: "Food", yearMonth: currentMonth, limitAmount: 500))

        let vm = makeViewModel()
        await vm.load()

        let food = try XCTUnwrap(vm.categoryTotals.first(where: { $0.category == "Food" }))
        XCTAssertEqual(try XCTUnwrap(food.limit), 500, accuracy: 0.01)
    }

    // MARK: - BudgetGoal auto-carry

    func testAutoCarryCopiesGoalsWhenNoneExistForCurrentMonth() async throws {
        let calendar = Calendar.current
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: .now)!
        let previousMonth = yearMonthString(from: previousMonthDate)
        let currentMonth = yearMonthString(from: .now)

        insert(BudgetGoal(categoryName: "Food", yearMonth: previousMonth, limitAmount: 500))

        let vm = makeViewModel()
        await vm.load()

        let context = ModelContext(container)
        let goals = try context.fetch(FetchDescriptor<BudgetGoal>()).filter { $0.yearMonth == currentMonth }
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.categoryName, "Food")
        XCTAssertEqual(try XCTUnwrap(goals.first).limitAmount, 500, accuracy: 0.01)
    }

    func testAutoCarryNotCalledWhenGoalsAlreadyExist() async throws {
        let currentMonth = yearMonthString(from: .now)
        insert(BudgetGoal(categoryName: "Food", yearMonth: currentMonth, limitAmount: 300))

        let vm = makeViewModel()
        await vm.load()

        let context = ModelContext(container)
        let goals = try context.fetch(FetchDescriptor<BudgetGoal>()).filter { $0.yearMonth == currentMonth }
        XCTAssertEqual(goals.count, 1)
    }

    // MARK: - recurringStatus

    func testRecurringStatusDispatchedTrueWhenLastDispatchedMonthMatches() async throws {
        let currentMonth = yearMonthString(from: .now)
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 1,
            categoryName: "Assinaturas",
            isActive: true,
            lastDispatchedMonth: currentMonth
        )
        insert(payment)

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.recurringStatus.count, 1)
        XCTAssertTrue(vm.recurringStatus.first?.dispatched == true)
    }

    func testRecurringStatusDispatchedFalseWhenNotDispatched() async throws {
        let payment = RecurringPayment(
            name: "Spotify",
            amount: 21.90,
            dueDay: 10,
            categoryName: "Assinaturas",
            isActive: true,
            lastDispatchedMonth: nil
        )
        insert(payment)

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.recurringStatus.count, 1)
        XCTAssertTrue(vm.recurringStatus.first?.dispatched == false)
    }

    // MARK: - Pull-to-refresh

    func testRefreshIncrementsFetchCount() async throws {
        let vm = makeViewModel()
        await vm.load()
        let countAfterLoad = mockNotion.queryTransactionsCallCount

        await vm.refresh()

        XCTAssertGreaterThan(mockNotion.queryTransactionsCallCount, countAfterLoad)
    }

    // MARK: - monthlyTrend

    func testMonthlyTrendHasSixEntries() async throws {
        let calendar = Calendar.current
        let now = Date.now
        var transactions: [Transaction] = []
        for offset in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -offset, to: now) {
                transactions.append(Transaction(name: "Tx", amount: 100, date: date))
            }
        }
        mockNotion = MockNotionService(transactionsByDatabase: ["db-1": transactions])

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.monthlyTrend.count, 6)
    }

    // MARK: - Empty state

    func testEmptyStateWhenNoTransactions() async throws {
        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.currentMonthTotal, 0, accuracy: 0.01)
        XCTAssertTrue(vm.categoryTotals.isEmpty)
    }
}
