import Foundation

struct PendingTransactionPayload: Codable {
    let transaction: Transaction
    let databaseId: String
}
