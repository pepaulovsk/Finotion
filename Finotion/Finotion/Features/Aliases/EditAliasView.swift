import SwiftUI

struct EditAliasView: View {
    @Environment(\.dismiss) private var dismiss
    let merchantAlias: MerchantAlias
    let viewModel: MerchantAliasViewModel

    @State private var aliasText: String

    init(merchantAlias: MerchantAlias, viewModel: MerchantAliasViewModel) {
        self.merchantAlias = merchantAlias
        self.viewModel = viewModel
        _aliasText = State(initialValue: merchantAlias.alias ?? "")
    }

    private var isValid: Bool {
        !aliasText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Merchant") {
                    Text(merchantAlias.rawName)
                        .foregroundStyle(.secondary)
                }
                Section("Apelido") {
                    TextField("Nome amigável", text: $aliasText)
                }
                if merchantAlias.alias != nil {
                    Section {
                        Button("Limpar apelido", role: .destructive) {
                            viewModel.clearAlias(for: merchantAlias.rawName)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Editar Apelido")
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
        let trimmed = aliasText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        viewModel.setAlias(trimmed, for: merchantAlias.rawName)
        dismiss()
    }
}
