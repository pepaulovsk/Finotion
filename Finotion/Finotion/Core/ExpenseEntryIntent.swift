import Foundation

struct ExpenseEntryIntent: Equatable {
    var merchant: String?
    var amount: Double?
    var paymentMethod: String?
    var date: Date?
}
