import SwiftData

enum DataContainer {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            RecurringPayment.self,
            BudgetGoal.self,
            MerchantAlias.self,
            PendingEntry.self
        ])
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.finotion.app")
            )
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
