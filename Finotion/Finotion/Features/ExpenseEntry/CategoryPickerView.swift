import SwiftUI

struct CategoryPickerView: View {
    @Binding var selection: String
    let categories: [String]
    let onAddNew: (String) async -> Void

    @State private var searchText = ""
    @State private var isAddingNew = false

    private var filtered: [String] {
        searchText.isEmpty ? categories : categories.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var canAddNew: Bool {
        !searchText.isEmpty && !categories.contains(where: { $0.lowercased() == searchText.lowercased() })
    }

    var body: some View {
        List {
            if canAddNew {
                Button {
                    let new = searchText
                    Task {
                        await onAddNew(new)
                        selection = new
                    }
                } label: {
                    Label("Add \"\(searchText)\"", systemImage: "plus.circle")
                }
            }
            ForEach(filtered, id: \.self) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack {
                        Text(cat)
                        Spacer()
                        if selection == cat {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .searchable(text: $searchText, prompt: "Search or add category")
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}
