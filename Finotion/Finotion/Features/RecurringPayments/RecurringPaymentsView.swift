import SwiftData
import SwiftUI

struct RecurringPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RecurringPaymentsViewModel?
    @State private var showingAddSheet = false
    @State private var editingPayment: RecurringPayment?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    paymentsList(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Pagamentos Fixos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                if let vm = viewModel {
                    AddEditRecurringPaymentView(viewModel: vm, payment: nil)
                }
            }
            .sheet(item: $editingPayment) { payment in
                if let vm = viewModel {
                    AddEditRecurringPaymentView(viewModel: vm, payment: payment)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RecurringPaymentsViewModel(context: modelContext)
            }
        }
    }

    @ViewBuilder
    private func paymentsList(vm: RecurringPaymentsViewModel) -> some View {
        List {
            ForEach(vm.payments) { payment in
                RecurringPaymentRow(payment: payment, isDispatched: vm.currentMonthStatus(for: payment))
                    .contentShape(Rectangle())
                    .onTapGesture { editingPayment = payment }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    vm.delete(vm.payments[index])
                }
            }
        }
        .overlay {
            if vm.payments.isEmpty {
                ContentUnavailableView(
                    "Sem pagamentos fixos",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Toque em + para adicionar.")
                )
            }
        }
    }
}

private struct RecurringPaymentRow: View {
    let payment: RecurringPayment
    let isDispatched: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.name)
                    .font(.body)
                    .foregroundStyle(payment.isActive ? .primary : .secondary)
                HStack(spacing: 8) {
                    Text("Dia \(payment.dueDay)")
                    Text(payment.categoryName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.amount, format: .currency(code: "BRL"))
                    .font(.body.monospacedDigit())
                if isDispatched {
                    Label("Enviado", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !payment.isActive {
                    Text("Inativo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
