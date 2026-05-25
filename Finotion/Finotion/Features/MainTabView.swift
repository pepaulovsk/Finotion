import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.notionService) private var notionService
    @Environment(\.categoryService) private var categoryService
    @Environment(\.syncService) private var syncService
    @Environment(\.modelContext) private var modelContext
    @State private var showingExpenseEntry = false
    @State private var entryViewModel: ExpenseEntryViewModel?

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
            Button("Add Expense") { presentEntry(intent: nil) }
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
            RecurringPaymentsView()
                .tabItem { Label("Fixos", systemImage: "arrow.clockwise.circle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .sheet(isPresented: $showingExpenseEntry) {
            if let vm = entryViewModel {
                ExpenseEntryView(viewModel: vm, isPresented: $showingExpenseEntry)
            }
        }
        .onChange(of: appState.pendingIntent) { _, intent in
            guard let intent else { return }
            presentEntry(intent: intent)
            appState.pendingIntent = nil
        }
    }

    private func presentEntry(intent: ExpenseEntryIntent?) {
        guard let mapping = appState.fieldMapping else { return }
        entryViewModel = ExpenseEntryViewModel(
            notionService: notionService,
            categoryService: categoryService,
            aliasService: MerchantAliasService(context: modelContext),
            syncService: syncService,
            fieldMapping: mapping,
            intent: intent
        )
        showingExpenseEntry = true
    }
}
