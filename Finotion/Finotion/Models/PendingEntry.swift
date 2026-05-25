import SwiftData
import Foundation

@Model
final class PendingEntry {
    @Attribute(.unique) var id: UUID
    var transactionData: Data
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var status: String

    init(
        id: UUID = UUID(),
        transactionData: Data,
        createdAt: Date = .now,
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        status: String = "pending"
    ) {
        self.id = id
        self.transactionData = transactionData
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.status = status
    }
}
