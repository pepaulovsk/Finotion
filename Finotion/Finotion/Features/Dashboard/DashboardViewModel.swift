import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class DashboardViewModel {
    private(set) var currentMonthTotal: Double = 0
    private(set) var categoryTotals: [(category: String, spent: Double, limit: Double?)] = []
    private(set) var recentTransactions: [Transaction] = []
    private(set) var recurringStatus: [(payment: RecurringPayment, dispatched: Bool)] = []
    private(set) var monthlyTrend: [(yearMonth: String, total: Double)] = []
    private(set) var isLoading = false
    private(set) var showSkeleton = false

    private let notionService: any NotionService
    private let categoryService: CategoryService
    private let container: ModelContainer
    private let fieldMapping: FieldMapping

    init(
        notionService: any NotionService,
        categoryService: CategoryService,
        container: ModelContainer,
        fieldMapping: FieldMapping
    ) {
        self.notionService = notionService
        self.categoryService = categoryService
        self.container = container
        self.fieldMapping = fieldMapping
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true

        let skeletonTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { self?.showSkeleton = true }
        }

        await fetchAllData()

        skeletonTask.cancel()
        showSkeleton = false
        isLoading = false
    }

    func refresh() async {
        categoryService.invalidate()
        await fetchAllData()
    }

    // MARK: - Private

    private func fetchAllData() async {
        let calendar = Calendar.current
        let now = Date.now
        let currentYearMonth = yearMonthString(from: now)

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let sixMonthsAgo = calendar.date(byAdding: .month, value: -5, to: startOfMonth) else { return }

        async let currentFetch = fetchTransactions(start: startOfMonth, end: now)
        async let trendFetch = fetchTransactions(start: sixMonthsAgo, end: now)

        let (currentTx, trendTx) = await (currentFetch, trendFetch)

        processCurrentMonth(transactions: currentTx, yearMonth: currentYearMonth)
        processTrend(trendTransactions: trendTx, currentYearMonth: currentYearMonth, currentMonthTx: currentTx)
        processRecurring(currentYearMonth: currentYearMonth)
        triggerAutoCarry(currentYearMonth: currentYearMonth, calendar: calendar, now: now)
    }

    private func fetchTransactions(start: Date, end: Date) async -> [Transaction] {
        let filter = NotionFilter(startDate: start, endDate: end)
        return (try? await notionService.queryTransactions(databaseId: fieldMapping.databaseId, filter: filter)) ?? []
    }

    private func processCurrentMonth(transactions: [Transaction], yearMonth: String) {
        currentMonthTotal = transactions.reduce(0) { $0 + $1.amount }
        recentTransactions = Array(transactions.prefix(10))

        let goals = fetchGoals(yearMonth: yearMonth)
        let limitByCategory = Dictionary(uniqueKeysWithValues: goals.map { ($0.categoryName, $0.limitAmount) })
        let grouped = Dictionary(grouping: transactions) { $0.category ?? "Sem categoria" }
        categoryTotals = grouped
            .map { cat, txs in (category: cat, spent: txs.reduce(0) { $0 + $1.amount }, limit: limitByCategory[cat]) }
            .sorted { $0.category < $1.category }
    }

    private func processTrend(trendTransactions: [Transaction], currentYearMonth: String, currentMonthTx: [Transaction]) {
        let historical = trendTransactions.filter { yearMonthString(from: $0.date) != currentYearMonth }
        var grouped = Dictionary(grouping: historical) { yearMonthString(from: $0.date) }
        grouped[currentYearMonth] = currentMonthTx

        let calendar = Calendar.current
        let now = Date.now
        monthlyTrend = (0..<6).reversed().compactMap { offset -> (yearMonth: String, total: Double)? in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let key = yearMonthString(from: month)
            let total = (grouped[key] ?? []).reduce(0) { $0 + $1.amount }
            return (yearMonth: key, total: total)
        }
    }

    private func processRecurring(currentYearMonth: String) {
        let context = ModelContext(container)
        let payments = (try? context.fetch(FetchDescriptor<RecurringPayment>())) ?? []
        recurringStatus = payments.map { payment in
            (payment: payment, dispatched: payment.lastDispatchedMonth == currentYearMonth)
        }
    }

    private func triggerAutoCarry(currentYearMonth: String, calendar: Calendar, now: Date) {
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else { return }
        let previousMonth = yearMonthString(from: previousMonthDate)
        let context = ModelContext(container)
        try? BudgetGoalService.autoCarry(from: previousMonth, to: currentYearMonth, context: context)
    }

    private func fetchGoals(yearMonth: String) -> [BudgetGoal] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BudgetGoal>(predicate: #Predicate { $0.yearMonth == yearMonth })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func yearMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
