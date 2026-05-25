import SwiftData
import Foundation

@Model
final class RecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    var dueDay: Int
    var categoryName: String
    var paymentMethod: String?
    var isActive: Bool
    var lastDispatchedMonth: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        dueDay: Int,
        categoryName: String,
        paymentMethod: String? = nil,
        isActive: Bool = true,
        lastDispatchedMonth: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.categoryName = categoryName
        self.paymentMethod = paymentMethod
        self.isActive = isActive
        self.lastDispatchedMonth = lastDispatchedMonth
        self.createdAt = createdAt
    }
}
