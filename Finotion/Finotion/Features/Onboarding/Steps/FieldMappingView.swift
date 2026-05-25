import SwiftUI

struct FieldMappingView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var propertyNames: [String] { viewModel.databaseProperties.map(\.name) }
    private var optionalOptions: [String] { [""] + propertyNames }

    var body: some View {
        Form {
            Section {
                Text("Map your Notion database fields to Finotion concepts. Name, Amount, and Date are required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Required Fields") {
                fieldPicker("Name", selection: $viewModel.nameField, options: propertyNames)
                fieldPicker("Amount", selection: $viewModel.amountField, options: propertyNames)
                fieldPicker("Date", selection: $viewModel.dateField, options: propertyNames)
            }

            Section("Optional Fields") {
                fieldPicker("Type", selection: $viewModel.typeField, options: optionalOptions)
                fieldPicker("Category", selection: $viewModel.categoryField, options: optionalOptions)
                fieldPicker("Payment Method", selection: $viewModel.paymentMethodField, options: optionalOptions)
                fieldPicker("Reference Date", selection: $viewModel.refDateField, options: optionalOptions)
            }

            Section {
                Button("Confirm Mapping") {
                    viewModel.confirmFieldMapping()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(!canConfirm)
            }
        }
        .navigationTitle("Map Fields")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canConfirm: Bool {
        !viewModel.nameField.isEmpty && !viewModel.amountField.isEmpty && !viewModel.dateField.isEmpty
    }

    private func fieldPicker(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.self) { name in
                Text(name.isEmpty ? "—" : name).tag(name)
            }
        }
    }
}
