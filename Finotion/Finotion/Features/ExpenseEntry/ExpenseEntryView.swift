import SwiftUI
import UIKit

struct ExpenseEntryView: View {
    @Bindable var viewModel: ExpenseEntryViewModel
    @Binding var isPresented: Bool
    @State private var showCategoryPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Merchant / Name", text: $viewModel.name)
                    HStack {
                        Text("R$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                }

                Section("Optional") {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(viewModel.category.isEmpty ? "None" : viewModel.category)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    TextField("Payment Method", text: $viewModel.paymentMethod)
                    TextField("Description", text: $viewModel.descriptionText)
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        viewModel.save()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .navigationDestination(isPresented: $showCategoryPicker) {
                CategoryPickerView(
                    selection: $viewModel.category,
                    categories: viewModel.categories,
                    onAddNew: { name in await viewModel.addNewCategory(name) }
                )
            }
        }
        .task { await viewModel.loadCategories() }
        .onChange(of: viewModel.shouldDismiss) { _, should in
            if should { isPresented = false }
        }
    }
}
