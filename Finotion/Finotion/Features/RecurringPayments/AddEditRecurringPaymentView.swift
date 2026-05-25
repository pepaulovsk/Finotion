import SwiftUI

struct AddEditRecurringPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: RecurringPaymentsViewModel
    let payment: RecurringPayment?

    @State private var name: String
    @State private var amountText: String
    @State private var dueDay: Int
    @State private var categoryName: String
    @State private var paymentMethod: String
    @State private var isActive: Bool

    private var isEditing: Bool { payment != nil }

    init(viewModel: RecurringPaymentsViewModel, payment: RecurringPayment?) {
        self.viewModel = viewModel
        self.payment = payment
        _name = State(initialValue: payment?.name ?? "")
        _amountText = State(initialValue: payment.map { String($0.amount) } ?? "")
        _dueDay = State(initialValue: payment?.dueDay ?? 1)
        _categoryName = State(initialValue: payment?.categoryName ?? "")
        _paymentMethod = State(initialValue: payment?.paymentMethod ?? "")
        _isActive = State(initialValue: payment?.isActive ?? true)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(amountText) ?? 0) > 0 &&
        !categoryName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados") {
                    TextField("Nome", text: $name)
                    TextField("Valor", text: $amountText)
                        .keyboardType(.decimalPad)
                    Stepper("Dia \(dueDay)", value: $dueDay, in: 1...31)
                }
                Section("Categorização") {
                    TextField("Categoria", text: $categoryName)
                    TextField("Método de pagamento", text: $paymentMethod)
                }
                Section {
                    Toggle("Ativo", isOn: $isActive)
                }
            }
            .navigationTitle(isEditing ? "Editar" : "Novo Pagamento Fixo")
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
        guard let amount = Double(amountText), amount > 0 else { return }
        if let existing = payment {
            existing.name = name
            existing.amount = amount
            existing.dueDay = dueDay
            existing.categoryName = categoryName
            existing.paymentMethod = paymentMethod.isEmpty ? nil : paymentMethod
            existing.isActive = isActive
            viewModel.update()
        } else {
            let newPayment = RecurringPayment(
                name: name,
                amount: amount,
                dueDay: dueDay,
                categoryName: categoryName,
                paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
                isActive: isActive
            )
            viewModel.add(newPayment)
        }
        dismiss()
    }
}
