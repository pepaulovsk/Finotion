import Foundation

struct FieldMapping: Codable, Equatable {
    var databaseId: String
    var nameField: String
    var amountField: String
    var dateField: String
    var typeField: String?
    var categoryField: String?
    var paymentMethodField: String?
    var refDateField: String?
}
