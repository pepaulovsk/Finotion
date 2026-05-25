import Foundation
import Observation

@Observable
final class ExpenseEntryViewModel {
    var name = ""
    var amountText = ""
    var category = ""
    var paymentMethod = ""
    var date: Date = .now
    var descriptionText = ""
    var shouldDismiss = false
    var categories: [String] = []
    var isLoadingCategories = false

    var amount: Double? { Double(amountText) }
    var isValid: Bool { !name.isEmpty && amount != nil && (amount ?? 0) > 0 }

    private let notionService: any NotionService
    private let categoryService: CategoryService
    private let aliasService: any MerchantAliasServiceProtocol
    private let syncService: any SyncServiceProtocol
    private let fieldMapping: FieldMapping

    init(
        notionService: any NotionService,
        categoryService: CategoryService,
        aliasService: any MerchantAliasServiceProtocol,
        syncService: any SyncServiceProtocol,
        fieldMapping: FieldMapping,
        intent: ExpenseEntryIntent? = nil
    ) {
        self.notionService = notionService
        self.categoryService = categoryService
        self.aliasService = aliasService
        self.syncService = syncService
        self.fieldMapping = fieldMapping

        if let intent {
            name = intent.merchant ?? ""
            amountText = intent.amount.map { String($0) } ?? ""
            paymentMethod = intent.paymentMethod ?? ""
            date = intent.date ?? .now
        }
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        categories = (try? await categoryService.fetchCategories(databaseId: fieldMapping.databaseId)) ?? []
    }

    func addNewCategory(_ name: String) async {
        guard !name.isEmpty else { return }
        let propertyId = fieldMapping.categoryField ?? ""
        try? await categoryService.addCategory(name, databaseId: fieldMapping.databaseId, propertyId: propertyId)
        if !categories.contains(name) { categories.append(name) }
    }

    func save() {
        guard isValid, let amount else { return }
        let rawName = name
        let txId = UUID()
        let tx = Transaction(
            id: txId,
            name: rawName,
            amount: amount,
            date: date,
            category: category.isEmpty ? nil : category,
            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
            description: descriptionText.isEmpty ? "id:\(txId)" : "\(descriptionText) [id:\(txId)]",
            type: .expense
        )
        let databaseId = fieldMapping.databaseId
        shouldDismiss = true

        Task { [notionService, aliasService, syncService] in
            let resolvedName = await aliasService.resolve(rawName: rawName)
            await aliasService.register(rawName: rawName)
            let resolved = Transaction(
                id: tx.id, name: resolvedName, amount: tx.amount, date: tx.date,
                category: tx.category, paymentMethod: tx.paymentMethod,
                description: tx.description, type: tx.type
            )
            do {
                _ = try await notionService.createTransaction(resolved, databaseId: databaseId)
            } catch {
                let payload = PendingTransactionPayload(transaction: resolved, databaseId: databaseId)
                let entryData = (try? JSONEncoder().encode(payload)) ?? Data()
                let pendingEntry = PendingEntry(id: resolved.id, transactionData: entryData)
                await syncService.enqueue(pendingEntry)
            }
        }
    }

    func reset() {
        name = ""
        amountText = ""
        category = ""
        paymentMethod = ""
        date = .now
        descriptionText = ""
        shouldDismiss = false
    }
}
