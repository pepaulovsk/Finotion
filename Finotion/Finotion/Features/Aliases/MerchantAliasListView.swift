import SwiftData
import SwiftUI

struct MerchantAliasListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MerchantAliasViewModel?
    @State private var selectedAlias: MerchantAlias?

    var body: some View {
        Group {
            if let vm = viewModel {
                aliasList(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Apelidos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAlias) { alias in
            if let vm = viewModel {
                EditAliasView(merchantAlias: alias, viewModel: vm)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = MerchantAliasViewModel(context: modelContext)
            }
        }
    }

    @ViewBuilder
    private func aliasList(vm: MerchantAliasViewModel) -> some View {
        List {
            if !vm.unnamed.isEmpty {
                Section("Sem apelido") {
                    ForEach(vm.unnamed) { alias in
                        Button {
                            selectedAlias = alias
                        } label: {
                            Text(alias.rawName)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            if !vm.named.isEmpty {
                Section("Com apelido") {
                    ForEach(vm.named) { alias in
                        Button {
                            selectedAlias = alias
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alias.alias ?? "")
                                    .foregroundStyle(.primary)
                                Text(alias.rawName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if vm.unnamed.isEmpty && vm.named.isEmpty {
                ContentUnavailableView(
                    "Sem merchants",
                    systemImage: "person.crop.rectangle",
                    description: Text("Adicione uma despesa para começar.")
                )
            }
        }
    }
}
