import BackgroundTasks
import Foundation
import SwiftData
import UserNotifications

// MARK: - NotificationScheduling

protocol NotificationScheduling: Sendable {
    func schedule(title: String, body: String, identifier: String) async
}

struct LiveNotificationScheduler: NotificationScheduling, Sendable {
    func schedule(title: String, body: String, identifier: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}

// MARK: - RecurringDispatchService

final class RecurringDispatchService: @unchecked Sendable {

    var scheduleNextTask: @Sendable () -> Void = {
        let request = BGAppRefreshTaskRequest(identifier: "com.finotion.recurring-dispatch")
        let calendar = Calendar.current
        request.earliestBeginDate = calendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 8, minute: 0),
            matchingPolicy: .nextTime
        )
        try? BGTaskScheduler.shared.submit(request)
    }

    private let notionService: any NotionService
    private let container: ModelContainer
    private let fieldMappingProvider: @Sendable () -> FieldMapping?
    private let notificationScheduler: any NotificationScheduling

    init(
        notionService: any NotionService,
        container: ModelContainer,
        fieldMappingProvider: @escaping @Sendable () -> FieldMapping?,
        notificationScheduler: any NotificationScheduling = LiveNotificationScheduler()
    ) {
        self.notionService = notionService
        self.container = container
        self.fieldMappingProvider = fieldMappingProvider
        self.notificationScheduler = notificationScheduler
    }

    func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        scheduleNextTask()
        guard let mapping = fieldMappingProvider() else {
            task.setTaskCompleted(success: false)
            return
        }
        await dispatch(databaseId: mapping.databaseId, on: .now)
        task.setTaskCompleted(success: true)
    }

    func dispatch(databaseId: String, on date: Date) async {
        let calendar = Calendar.current
        let yearMonth = yearMonthString(from: date)
        let todayDay = calendar.component(.day, from: date)
        let lastDayOfMonth = (calendar.range(of: .day, in: .month, for: date)?.upperBound ?? 29) - 1

        let eligibleIds = fetchEligiblePaymentIds(
            todayDay: todayDay,
            lastDayOfMonth: lastDayOfMonth,
            yearMonth: yearMonth
        )
        for id in eligibleIds {
            await processPayment(id: id, databaseId: databaseId, yearMonth: yearMonth)
        }
    }

    // MARK: - Private helpers

    private struct PaymentSnapshot: Sendable {
        let id: UUID
        let name: String
        let amount: Double
        let categoryName: String
        let paymentMethod: String?
    }

    private func fetchEligiblePaymentIds(todayDay: Int, lastDayOfMonth: Int, yearMonth: String) -> [UUID] {
        let context = ModelContext(container)
        guard let payments = try? context.fetch(FetchDescriptor<RecurringPayment>()) else { return [] }
        return payments.compactMap { payment in
            guard payment.isActive else { return nil }
            guard payment.lastDispatchedMonth != yearMonth else { return nil }
            let effectiveDay = min(payment.dueDay, lastDayOfMonth)
            guard todayDay == effectiveDay else { return nil }
            return payment.id
        }
    }

    private func fetchSnapshot(id: UUID) -> PaymentSnapshot? {
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<RecurringPayment>())) ?? []
        guard let payment = all.first(where: { $0.id == id }) else { return nil }
        return PaymentSnapshot(
            id: payment.id,
            name: payment.name,
            amount: payment.amount,
            categoryName: payment.categoryName,
            paymentMethod: payment.paymentMethod
        )
    }

    private func updateLastDispatched(id: UUID, yearMonth: String) {
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<RecurringPayment>())) ?? []
        guard let payment = all.first(where: { $0.id == id }) else { return }
        payment.lastDispatchedMonth = yearMonth
        try? context.save()
    }

    private func processPayment(id: UUID, databaseId: String, yearMonth: String) async {
        guard let snapshot = fetchSnapshot(id: id) else { return }
        let recurringKey = "[recurringId:\(id.uuidString)][month:\(yearMonth)]"
        let filter = NotionFilter(recurringKey: recurringKey)

        var success = false
        let existing = (try? await notionService.queryTransactions(databaseId: databaseId, filter: filter)) ?? []
        if !existing.isEmpty {
            success = true
        } else {
            let tx = Transaction(
                name: snapshot.name,
                amount: snapshot.amount,
                category: snapshot.categoryName,
                paymentMethod: snapshot.paymentMethod,
                description: recurringKey
            )
            do {
                _ = try await notionService.createTransaction(tx, databaseId: databaseId)
                success = true
            } catch {
                success = false
            }
        }

        if success {
            updateLastDispatched(id: id, yearMonth: yearMonth)
            await notificationScheduler.schedule(
                title: "Pagamento enviado",
                body: "\(snapshot.name) foi lançado no Notion.",
                identifier: "dispatch-success-\(id.uuidString)"
            )
        } else {
            await notificationScheduler.schedule(
                title: "Falha no lançamento",
                body: "\(snapshot.name) não pôde ser enviado. Tente novamente mais tarde.",
                identifier: "dispatch-failure-\(id.uuidString)"
            )
        }
    }

    private func yearMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
