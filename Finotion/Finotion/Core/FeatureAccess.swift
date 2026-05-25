protocol FeatureAccess {
    var recurringPayments: Bool { get }
    var merchantAliases: Bool { get }
    var notificationCapture: Bool { get }
    var incomeTracking: Bool { get }
}

struct FullAccess: FeatureAccess {
    var recurringPayments: Bool { true }
    var merchantAliases: Bool { true }
    var notificationCapture: Bool { false }
    var incomeTracking: Bool { false }
}
