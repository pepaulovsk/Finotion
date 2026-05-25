import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.notionService) private var notionService
    @Environment(\.categoryService) private var categoryService
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @State private var goalEditItem: GoalEditItem?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.showSkeleton {
                        skeletonView
                    } else {
                        dashboardContent(vm: vm)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                guard let vm = viewModel else { return }
                await vm.refresh()
            }
            .sheet(item: $goalEditItem) { item in
                SetBudgetGoalView(
                    category: item.category,
                    yearMonth: item.yearMonth,
                    currentLimit: item.currentLimit
                ) {
                    Task { await viewModel?.refresh() }
                }
            }
        }
        .onAppear {
            guard viewModel == nil, let mapping = appState.fieldMapping else { return }
            let vm = DashboardViewModel(
                notionService: notionService,
                categoryService: categoryService,
                container: modelContext.container,
                fieldMapping: mapping
            )
            viewModel = vm
            Task { await vm.load() }
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        List {
            Section {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 60)
            }
            Section {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 40)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Content

    @ViewBuilder
    private func dashboardContent(vm: DashboardViewModel) -> some View {
        List {
            monthlyTotalSection(vm: vm)
            categorySection(vm: vm)
            recentSection(vm: vm)
            recurringSection(vm: vm)
            trendSection(vm: vm)
        }
    }

    // MARK: - Monthly Total

    private func monthlyTotalSection(vm: DashboardViewModel) -> some View {
        Section("Mês atual") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total gasto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(vm.currentMonthTotal, format: .currency(code: "BRL"))
                    .font(.title.bold())
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Categories

    @ViewBuilder
    private func categorySection(vm: DashboardViewModel) -> some View {
        Section("Categorias") {
            if vm.categoryTotals.isEmpty {
                Text("Nenhuma transação este mês.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(vm.categoryTotals, id: \.category) { item in
                    Button {
                        goalEditItem = GoalEditItem(
                            category: item.category,
                            yearMonth: currentYearMonth,
                            currentLimit: item.limit
                        )
                    } label: {
                        CategoryRow(category: item.category, spent: item.spent, limit: item.limit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent Transactions

    @ViewBuilder
    private func recentSection(vm: DashboardViewModel) -> some View {
        Section("Recentes") {
            if vm.recentTransactions.isEmpty {
                Text("Nenhuma transação registrada.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(vm.recentTransactions) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.name).font(.body)
                            if let cat = tx.category {
                                Text(cat).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(tx.amount, format: .currency(code: "BRL"))
                            .font(.body.monospacedDigit())
                    }
                }
            }
        }
    }

    // MARK: - Recurring

    @ViewBuilder
    private func recurringSection(vm: DashboardViewModel) -> some View {
        Section("Pagamentos Fixos") {
            if vm.recurringStatus.isEmpty {
                Text("Nenhum pagamento fixo configurado.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(vm.recurringStatus, id: \.payment.id) { item in
                    HStack {
                        Text(item.payment.name)
                        Spacer()
                        if item.dispatched {
                            Label("Enviado", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Pendente")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private func trendSection(vm: DashboardViewModel) -> some View {
        Section("Tendência (6 meses)") {
            if vm.monthlyTrend.allSatisfy({ $0.total == 0 }) {
                Text("Dados insuficientes para o gráfico.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                Chart(vm.monthlyTrend, id: \.yearMonth) { item in
                    BarMark(
                        x: .value("Mês", item.yearMonth),
                        y: .value("Total", item.total)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .frame(height: 160)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Helpers

    private var currentYearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: .now)
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: String
    let spent: Double
    let limit: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category)
                Spacer()
                Text(spent, format: .currency(code: "BRL"))
                    .font(.body.monospacedDigit())
                if let limit {
                    Text("/ \(limit, format: .currency(code: "BRL"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let limit, limit > 0 {
                ProgressView(value: min(spent, limit), total: limit)
                    .tint(spent > limit ? .red : .accentColor)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Goal Edit Item

private struct GoalEditItem: Identifiable {
    let id: String
    let category: String
    let yearMonth: String
    let currentLimit: Double?

    init(category: String, yearMonth: String, currentLimit: Double?) {
        self.id = category
        self.category = category
        self.yearMonth = yearMonth
        self.currentLimit = currentLimit
    }
}
