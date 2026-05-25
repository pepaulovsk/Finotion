import Foundation

enum URLSchemeHandler {
    static func parse(_ url: URL) -> ExpenseEntryIntent? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "finotion",
              components.host == "add" else { return nil }

        let items = components.queryItems ?? []
        let merchant = items.first(where: { $0.name == "merchant" })?.value
        let paymentMethod = items.first(where: { $0.name == "paymentMethod" })?.value

        let amountString = items.first(where: { $0.name == "amount" })?.value
        let amount = amountString.flatMap { Double($0) }

        let dateString = items.first(where: { $0.name == "date" })?.value
        let date = dateString.flatMap { ISO8601DateFormatter().date(from: $0) }

        return ExpenseEntryIntent(
            merchant: merchant?.isEmpty == true ? nil : merchant,
            amount: amount,
            paymentMethod: paymentMethod?.isEmpty == true ? nil : paymentMethod,
            date: date
        )
    }
}
