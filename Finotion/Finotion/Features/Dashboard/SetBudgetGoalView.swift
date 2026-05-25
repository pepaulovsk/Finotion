import SwiftData
import SwiftUI

struct SetBudgetGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: String
    let yearMonth: String
    let currentLimit: Double?
    let onSave: () -> Void

    @State private var limitText: String

    init(category: String, yearMonth: String, currentLimit: Double?, onSave: @escaping () -> Void) {
        self.category = category
        self.yearMonth = yearMonth
        self.currentLimit = currentLimit
        self.onSave = onSave
        _limitText = State(initialValue: currentLimit.map { String($0) } ?? "")
    }

    private var isValid: Bool {
        (Double(limitText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(category)
                        .font(.headline)
                }
                Section("Limite mensal (R$)") {
                    TextField("Ex: 500", text: $limitText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Meta de Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let limit = Double(limitText), limit > 0 else { return }
        let descriptor = FetchDescriptor<BudgetGoal>(
            predicate: #Predicate { $0.categoryName == category && $0.yearMonth == yearMonth }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.limitAmount = limit
        } else {
            modelContext.insert(BudgetGoal(categoryName: category, yearMonth: yearMonth, limitAmount: limit))
        }
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
