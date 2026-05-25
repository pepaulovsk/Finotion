import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class RecurringPaymentsViewModel {
    private(set) var payments: [RecurringPayment] = []
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        fetch()
    }

    func fetch() {
        let descriptor = FetchDescriptor<RecurringPayment>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        payments = (try? context.fetch(descriptor)) ?? []
    }

    func add(_ payment: RecurringPayment) {
        context.insert(payment)
        try? context.save()
        fetch()
    }

    func update() {
        try? context.save()
        fetch()
    }

    func delete(_ payment: RecurringPayment) {
        context.delete(payment)
        try? context.save()
        fetch()
    }

    func currentMonthStatus(for payment: RecurringPayment) -> Bool {
        payment.lastDispatchedMonth == currentYearMonth()
    }

    private func currentYearMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: .now)
    }
}
