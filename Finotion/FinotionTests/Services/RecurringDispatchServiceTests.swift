import Foundation
import SwiftData
import XCTest
@testable import Finotion

// MARK: - Mock Helpers

final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var scheduledNotifications: [(title: String, body: String, identifier: String)] = []

    func schedule(title: String, body: String, identifier: String) async {
        scheduledNotifications.append((title, body, identifier))
    }
}

// MARK: - Tests

@MainActor
final class RecurringDispatchServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var mockNotion: MockNotionService!
    private var mockNotif: MockNotificationScheduler!
    private var service: RecurringDispatchService!
    private let mapping = FieldMapping(
        databaseId: "db-1",
        nameField: "Name",
        amountField: "Amount",
        dateField: "Date"
    )

    override func setUp() async throws {
        try await super.setUp()
        container = try DataContainer.makeContainer(inMemory: true)
        mockNotion = MockNotionService()
        mockNotif = MockNotificationScheduler()
        service = makeService()
    }

    // MARK: - Helpers

    private func makeService(notif: MockNotificationScheduler? = nil) -> RecurringDispatchService {
        let svc = RecurringDispatchService(
            notionService: mockNotion,
            container: container,
            fieldMappingProvider: { [mapping] in mapping },
            notificationScheduler: notif ?? mockNotif
        )
        svc.scheduleNextTask = {}
        return svc
    }

    private func insert(_ payment: RecurringPayment) {
        let context = ModelContext(container)
        context.insert(payment)
        try? context.save()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func fetchPayment(id: UUID) throws -> RecurringPayment? {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<RecurringPayment>()).first(where: { $0.id == id })
    }

    // MARK: - Skip already dispatched

    func testSkipsPaymentAlreadyDispatchedThisMonth() async throws {
        let yearMonth = "2026-05"
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true,
            lastDispatchedMonth: yearMonth
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertTrue(mockNotion.storedTransactions(in: "db-1").isEmpty)
    }

    // MARK: - Dispatch eligible payment

    func testDispatchesPaymentWhenNotYetDispatchedThisMonth() async throws {
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 1)
    }

    func testLastDispatchedMonthUpdatedAfterSuccess() async throws {
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        let updated = try fetchPayment(id: payment.id)
        XCTAssertEqual(updated?.lastDispatchedMonth, "2026-05")
    }

    // MARK: - Value versioning

    func testAmountChangeDoesNotResetLastDispatchedMonth() async throws {
        let yearMonth = "2026-05"
        let payment = RecurringPayment(
            name: "Spotify",
            amount: 21.90,
            dueDay: 10,
            categoryName: "Assinaturas",
            isActive: true,
            lastDispatchedMonth: yearMonth
        )
        insert(payment)

        // Simulate editing the amount — should not reset lastDispatchedMonth
        let context = ModelContext(container)
        if let fetched = try? context.fetch(FetchDescriptor<RecurringPayment>()).first(where: { $0.id == payment.id }) {
            fetched.amount = 29.90
            try? context.save()
        }

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 10))

        // Still skipped — lastDispatchedMonth was not reset
        XCTAssertTrue(mockNotion.storedTransactions(in: "db-1").isEmpty)
        let updated = try fetchPayment(id: payment.id)
        XCTAssertEqual(updated?.amount, 29.90)
        XCTAssertEqual(updated?.lastDispatchedMonth, yearMonth)
    }

    // MARK: - dueDay edge cases

    func testDueDay31In30DayMonthDispatchesOnDay30() async throws {
        let payment = RecurringPayment(
            name: "Aluguel",
            amount: 1500.0,
            dueDay: 31,
            categoryName: "Moradia",
            isActive: true
        )
        insert(payment)

        // April has 30 days; dispatch should happen on day 30
        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 4, day: 30))

        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 1)
    }

    func testDueDay31InFebruaryDispatchesOnLastDay() async throws {
        let payment = RecurringPayment(
            name: "Aluguel",
            amount: 1500.0,
            dueDay: 31,
            categoryName: "Moradia",
            isActive: true
        )
        insert(payment)

        // February 2025 has 28 days (non-leap)
        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2025, month: 2, day: 28))

        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 1)
    }

    // MARK: - Deduplication

    func testDeduplicationSkipsCreateWhenAlreadyInNotion() async throws {
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true
        )
        insert(payment)

        let yearMonth = "2026-05"
        let key = "[recurringId:\(payment.id.uuidString)][month:\(yearMonth)]"
        let existing = Transaction(
            name: "Netflix",
            amount: 55.90,
            description: key,
            type: .expense
        )
        mockNotion = MockNotionService(transactionsByDatabase: ["db-1": [existing]])
        service = makeService()

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        // createTransaction not called — still 1 entry (the pre-seeded one)
        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 1)
        let updated = try fetchPayment(id: payment.id)
        XCTAssertEqual(updated?.lastDispatchedMonth, yearMonth)
    }

    // MARK: - Notifications

    func testDispatchFiresSuccessNotification() async throws {
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertEqual(mockNotif.scheduledNotifications.count, 1)
        XCTAssertEqual(mockNotif.scheduledNotifications.first?.title, "Pagamento enviado")
    }

    func testDispatchFiresFailureNotificationAndDoesNotThrow() async throws {
        mockNotion.createTransactionError = .serverError(500)
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: true
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertEqual(mockNotif.scheduledNotifications.count, 1)
        XCTAssertEqual(mockNotif.scheduledNotifications.first?.title, "Falha no lançamento")
    }

    // MARK: - Inactive payments

    func testInactivePaymentsAreSkipped() async throws {
        let payment = RecurringPayment(
            name: "Netflix",
            amount: 55.90,
            dueDay: 15,
            categoryName: "Assinaturas",
            isActive: false
        )
        insert(payment)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertTrue(mockNotion.storedTransactions(in: "db-1").isEmpty)
    }

    // MARK: - ViewModel delete

    func testViewModelDeleteRemovesPayment() throws {
        let context = ModelContext(container)
        let vm = RecurringPaymentsViewModel(context: context)

        let payment = RecurringPayment(name: "Spotify", amount: 21.90, dueDay: 10, categoryName: "Assinaturas")
        vm.add(payment)
        XCTAssertEqual(vm.payments.count, 1)

        vm.delete(vm.payments[0])
        XCTAssertTrue(vm.payments.isEmpty)
    }

    // MARK: - Integration: partial dispatch

    func testIntegrationDispatchesOnlyEligiblePayments() async throws {
        let yearMonth = "2026-05"
        let p1 = RecurringPayment(name: "Netflix", amount: 55.90, dueDay: 15, categoryName: "Assinaturas", isActive: true)
        let p2 = RecurringPayment(name: "Spotify", amount: 21.90, dueDay: 15, categoryName: "Assinaturas", isActive: true)
        let p3 = RecurringPayment(
            name: "Já enviado",
            amount: 100.0,
            dueDay: 15,
            categoryName: "Outros",
            isActive: true,
            lastDispatchedMonth: yearMonth
        )
        insert(p1)
        insert(p2)
        insert(p3)

        await service.dispatch(databaseId: "db-1", on: makeDate(year: 2026, month: 5, day: 15))

        XCTAssertEqual(mockNotion.storedTransactions(in: "db-1").count, 2)
    }
}
