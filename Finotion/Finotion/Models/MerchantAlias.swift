import SwiftData
import Foundation

@Model
final class MerchantAlias {
    @Attribute(.unique) var rawName: String
    var alias: String?
    var seenAt: Date

    init(rawName: String, alias: String? = nil, seenAt: Date = .now) {
        self.rawName = rawName
        self.alias = alias
        self.seenAt = seenAt
    }
}
