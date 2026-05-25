import SwiftUI

struct EditFieldMappingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let databaseId: String

    @State private var nameField: String
    @State private var amountField: String
    @State private var dateField: String
    @State private var typeField: String
    @State private var categoryField: String
    @State private var paymentMethodField: String
    @State private var refDateField: String

    init(mapping: FieldMapping) {
        self.databaseId = mapping.databaseId
        _nameField = State(initialValue: mapping.nameField)
        _amountField = State(initialValue: mapping.amountField)
        _dateField = State(initialValue: mapping.dateField)
        _typeField = State(initialValue: mapping.typeField ?? "")
        _categoryField = State(initialValue: mapping.categoryField ?? "")
        _paymentMethodField = State(initialValue: mapping.paymentMethodField ?? "")
        _refDateField = State(initialValue: mapping.refDateField ?? "")
    }

    private var isValid: Bool {
        !nameField.trimmingCharacters(in: .whitespaces).isEmpty &&
        !amountField.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dateField.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Digite os nomes exatos das colunas no seu banco Notion.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Campos obrigatórios") {
                    LabeledContent("Nome") {
                        TextField("Ex: Nome", text: $nameField)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Valor") {
                        TextField("Ex: Valor", text: $amountField)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Data") {
                        TextField("Ex: Data", text: $dateField)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Campos opcionais") {
                    LabeledContent("Tipo") {
                        TextField("—", text: $typeField)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Categoria") {
                        TextField("—", text: $categoryField)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Método") {
                        TextField("—", text: $paymentMethodField)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Data Ref.") {
                        TextField("—", text: $refDateField)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Mapeamento de Campos")
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
        let updated = FieldMapping(
            databaseId: databaseId,
            nameField: nameField.trimmingCharacters(in: .whitespaces),
            amountField: amountField.trimmingCharacters(in: .whitespaces),
            dateField: dateField.trimmingCharacters(in: .whitespaces),
            typeField: typeField.trimmingCharacters(in: .whitespaces).isEmpty ? nil : typeField.trimmingCharacters(in: .whitespaces),
            categoryField: categoryField.trimmingCharacters(in: .whitespaces).isEmpty ? nil : categoryField.trimmingCharacters(in: .whitespaces),
            paymentMethodField: paymentMethodField.trimmingCharacters(in: .whitespaces).isEmpty ? nil : paymentMethodField.trimmingCharacters(in: .whitespaces),
            refDateField: refDateField.trimmingCharacters(in: .whitespaces).isEmpty ? nil : refDateField.trimmingCharacters(in: .whitespaces)
        )
        try? appState.updateFieldMapping(updated)
        dismiss()
    }
}
