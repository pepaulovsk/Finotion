import SwiftData
import Foundation

@Model
final class BudgetGoal {
    @Attribute(.unique) var id: UUID
    var categoryName: String
    var yearMonth: String
    var limitAmount: Double

    init(
        id: UUID = UUID(),
        categoryName: String,
        yearMonth: String,
        limitAmount: Double
    ) {
        self.id = id
        self.categoryName = categoryName
        self.yearMonth = yearMonth
        self.limitAmount = limitAmount
    }
}
