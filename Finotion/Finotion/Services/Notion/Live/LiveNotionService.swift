import Foundation
import OSLog

// MARK: - URLSession Protocol (for testability)

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - LiveNotionService

// LiveNotionService is @unchecked Sendable because the closure and existential
// properties are all independently Sendable; the compiler cannot verify this
// automatically for final classes with existential stored properties.
final class LiveNotionService: NotionService, @unchecked Sendable {

    private let keychainService: any KeychainServiceProtocol
    private let fieldMappingProvider: @Sendable () -> FieldMapping?
    private let session: any URLSessionProtocol
    private let requestQueue: NotionRequestQueue
    let rateLimitRetryDelay: TimeInterval
    private let logger = Logger(subsystem: "com.finotion.app", category: "NotionService")

    private static let baseURL = "https://api.notion.com/v1"
    private static let notionVersion = "2022-06-28"
    private static let descriptionField = "Descrição"

    init(
        keychainService: any KeychainServiceProtocol,
        fieldMappingProvider: @Sendable @escaping () -> FieldMapping?,
        session: any URLSessionProtocol = URLSession.shared,
        rateLimitRetryDelay: TimeInterval = 2.0
    ) {
        self.keychainService = keychainService
        self.fieldMappingProvider = fieldMappingProvider
        self.session = session
        self.requestQueue = NotionRequestQueue()
        self.rateLimitRetryDelay = rateLimitRetryDelay
    }

    // MARK: - NotionService

    func fetchDatabases() async throws -> [NotionDatabase] {
        let body: [String: Any] = ["filter": ["property": "object", "value": "database"]]
        let request = try buildRequest(path: "/search", method: "POST", body: body)
        let data = try await performRequest(request)
        let response = try decode(NotionSearchResponse.self, from: data)
        return response.results.map {
            NotionDatabase(id: $0.id, title: $0.title?.first?.plainText ?? "Untitled", url: $0.url)
        }
    }

    func fetchDatabaseProperties(_ id: String) async throws -> [NotionProperty] {
        let request = try buildRequest(path: "/databases/\(id)", method: "GET")
        let data = try await performRequest(request)
        let response = try decode(NotionDatabasePropertiesResponse.self, from: data)
        return response.properties.map { _, meta in
            NotionProperty(id: meta.id, name: meta.name, type: meta.type)
        }
    }

    func createDatabase(parentPageId: String) async throws -> NotionDatabase {
        let body: [String: Any] = [
            "parent": ["type": "page_id", "page_id": parentPageId],
            "title": [["type": "text", "text": ["content": "Finotion Finance"]]],
            "properties": templateDatabaseProperties()
        ]
        let request = try buildRequest(path: "/databases", method: "POST", body: body)
        let data = try await performRequest(request)
        let response = try decode(NotionDatabaseResponse.self, from: data)
        return NotionDatabase(
            id: response.id,
            title: response.title.first?.plainText ?? "Finotion Finance",
            url: response.url
        )
    }

    func queryTransactions(databaseId: String, filter: NotionFilter?) async throws -> [Transaction] {
        guard let mapping = fieldMappingProvider() else { throw NotionError.unauthorized }
        var body: [String: Any] = [
            "page_size": 100,
            "sorts": [["property": mapping.dateField, "direction": "descending"]]
        ]
        let conditions = buildFilterConditions(filter: filter, mapping: mapping)
        if conditions.count == 1 {
            body["filter"] = conditions[0]
        } else if conditions.count > 1 {
            body["filter"] = ["and": conditions]
        }
        let request = try buildRequest(path: "/databases/\(databaseId)/query", method: "POST", body: body)
        let data = try await performRequest(request)
        let response = try decode(NotionQueryResponse.self, from: data)
        return response.results.compactMap { transactionFrom(page: $0, mapping: mapping) }
    }

    func createTransaction(_ tx: Transaction, databaseId: String) async throws -> String {
        guard let mapping = fieldMappingProvider() else { throw NotionError.unauthorized }
        let pendingTag = "[pendingId:\(tx.id.uuidString)]"
        let descriptionContent = tx.description.map { "\($0) \(pendingTag)" } ?? pendingTag
        var properties: [String: Any] = [
            mapping.nameField: titleProperty(tx.name),
            mapping.amountField: ["number": tx.amount],
            mapping.dateField: dateProperty(tx.date),
            Self.descriptionField: richTextProperty(descriptionContent)
        ]
        if let category = tx.category, let catField = mapping.categoryField {
            properties[catField] = selectProperty(category)
        }
        if let paymentMethod = tx.paymentMethod, let pmField = mapping.paymentMethodField {
            properties[pmField] = selectProperty(paymentMethod)
        }
        if let typeField = mapping.typeField {
            properties[typeField] = selectProperty(tx.type.rawValue)
        }
        if let refDate = tx.refDate, let refDateField = mapping.refDateField {
            properties[refDateField] = dateProperty(refDate)
        }
        let body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": properties
        ]
        let request = try buildRequest(path: "/pages", method: "POST", body: body)
        let data = try await performRequest(request)
        let response = try decode(NotionCreatePageResponse.self, from: data)
        return response.id
    }

    func addCategoryOption(_ name: String, databaseId: String, propertyId: String) async throws {
        // Fetch current options; Notion replaces the full options list on PATCH
        let getRequest = try buildRequest(path: "/databases/\(databaseId)", method: "GET")
        let getData = try await performRequest(getRequest)
        let dbResponse = try decode(NotionDatabasePropertiesResponse.self, from: getData)

        var allOptions: [[String: Any]] = []
        if let prop = dbResponse.properties.values.first(where: { $0.id == propertyId }) {
            allOptions = (prop.select?.options ?? []).map { option in
                var dict: [String: Any] = ["name": option.name]
                if let id = option.id { dict["id"] = id }
                if let color = option.color { dict["color"] = color }
                return dict
            }
        }
        allOptions.append(["name": name])

        let patchBody: [String: Any] = [
            "properties": [propertyId: ["select": ["options": allOptions]]]
        ]
        let patchRequest = try buildRequest(path: "/databases/\(databaseId)", method: "PATCH", body: patchBody)
        _ = try await performRequest(patchRequest)
    }

    // MARK: - HTTP

    private func performRequest(_ request: URLRequest, isRetry: Bool = false) async throws -> Data {
        await requestQueue.waitForSlot()
        guard let token = keychainService.loadToken() else {
            throw NotionError.unauthorized
        }
        var req = request
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(Self.notionVersion, forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        logger.debug("→ \(req.httpMethod ?? "GET", privacy: .public) \(req.url?.absoluteString ?? "", privacy: .public)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            logger.error("Network error: \(urlError.localizedDescription, privacy: .public)")
            throw NotionError.networkError(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NotionError.serverError(0)
        }

        #if DEBUG
        logger.debug("← \(http.statusCode, privacy: .public)")
        #else
        if http.statusCode >= 400 {
            logger.warning("Request failed — status \(http.statusCode, privacy: .public)")
        }
        #endif

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw NotionError.unauthorized
        case 429:
            if isRetry { throw NotionError.rateLimited }
            logger.warning("Rate limited — retrying after \(self.rateLimitRetryDelay)s")
            try? await Task.sleep(for: .seconds(rateLimitRetryDelay))
            return try await performRequest(request, isRetry: true)
        default:
            throw NotionError.serverError(http.statusCode)
        }
    }

    // MARK: - Request Builder

    private func buildRequest(path: String, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: Self.baseURL + path) else { throw NotionError.serverError(0) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Decoding error: \(error.localizedDescription, privacy: .public)")
            throw NotionError.decodingError(error)
        }
    }

    // MARK: - Filter Builder

    private func buildFilterConditions(filter: NotionFilter?, mapping: FieldMapping) -> [[String: Any]] {
        guard let filter else { return [] }
        var conditions: [[String: Any]] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        if let start = filter.startDate {
            conditions.append(["property": mapping.dateField, "date": ["on_or_after": dateFormatter.string(from: start)]])
        }
        if let end = filter.endDate {
            conditions.append(["property": mapping.dateField, "date": ["on_or_before": dateFormatter.string(from: end)]])
        }
        if let category = filter.category, let catField = mapping.categoryField {
            conditions.append(["property": catField, "select": ["equals": category]])
        }
        if let pendingId = filter.pendingId {
            conditions.append(["property": Self.descriptionField, "rich_text": ["contains": pendingId]])
        }
        if let recurringKey = filter.recurringKey {
            conditions.append(["property": Self.descriptionField, "rich_text": ["contains": recurringKey]])
        }
        return conditions
    }

    // MARK: - Page to Transaction

    private func transactionFrom(page: NotionPage, mapping: FieldMapping) -> Transaction? {
        guard let nameProp = page.properties[mapping.nameField],
              let name = nameProp.textValue,
              !name.isEmpty,
              let amountProp = page.properties[mapping.amountField],
              let amount = amountProp.number else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var date = Date.now
        if let dateStr = page.properties[mapping.dateField]?.date?.start {
            date = dateFormatter.date(from: dateStr) ?? .now
        }
        var category: String?
        if let catField = mapping.categoryField {
            category = page.properties[catField]?.select?.name
        }
        var paymentMethod: String?
        if let pmField = mapping.paymentMethodField {
            paymentMethod = page.properties[pmField]?.select?.name
        }
        let description = page.properties[Self.descriptionField]?.textValue
        var type: TransactionType = .expense
        if let typeField = mapping.typeField,
           let typeStr = page.properties[typeField]?.select?.name {
            let lower = typeStr.lowercased()
            type = (lower == "income" || lower == "receita") ? .income : .expense
        }
        var refDate: Date?
        if let refDateField = mapping.refDateField,
           let refDateStr = page.properties[refDateField]?.date?.start {
            refDate = dateFormatter.date(from: refDateStr)
        }
        return Transaction(
            name: name,
            amount: amount,
            date: date,
            refDate: refDate,
            category: category,
            paymentMethod: paymentMethod,
            description: description,
            type: type
        )
    }

    // MARK: - Property Body Builders

    private func titleProperty(_ text: String) -> [String: Any] {
        ["title": [["text": ["content": text]]]]
    }

    private func richTextProperty(_ text: String) -> [String: Any] {
        ["rich_text": [["text": ["content": text]]]]
    }

    private func selectProperty(_ name: String) -> [String: Any] {
        ["select": ["name": name]]
    }

    private func dateProperty(_ date: Date) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return ["date": ["start": formatter.string(from: date)]]
    }

    // MARK: - Template Database Schema

    private func templateDatabaseProperties() -> [String: Any] {
        [
            "Nome": ["title": [String: Any]()],
            "Valor": ["number": ["format": "real"]],
            "Data": ["date": [String: Any]()],
            "Categoria": ["select": ["options": [
                ["name": "Alimentação"], ["name": "Transporte"], ["name": "Saúde"],
                ["name": "Lazer"], ["name": "Outros"]
            ]]],
            "Método de Pagamento": ["select": ["options": [
                ["name": "Débito"], ["name": "Crédito"], ["name": "Pix"], ["name": "Dinheiro"]
            ]]],
            "Tipo": ["select": ["options": [["name": "expense"], ["name": "income"]]]],
            "Data Referência": ["date": [String: Any]()],
            "Descrição": ["rich_text": [String: Any]()]
        ]
    }
}
