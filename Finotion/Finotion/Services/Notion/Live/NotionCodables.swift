import Foundation

// MARK: - Common

struct NotionRichText: Decodable {
    let plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

// MARK: - Search Response (GET /v1/search)

struct NotionSearchResponse: Decodable {
    let results: [NotionDatabaseResult]
}

struct NotionDatabaseResult: Decodable {
    let id: String
    let title: [NotionRichText]?
    let url: String?
}

// MARK: - Database Properties Response (GET /v1/databases/{id})

struct NotionDatabasePropertiesResponse: Decodable {
    let id: String
    let properties: [String: NotionPropertyMeta]
}

struct NotionPropertyMeta: Decodable {
    let id: String
    let name: String
    let type: String
    let select: NotionSelectMeta?
}

struct NotionSelectMeta: Decodable {
    let options: [NotionSelectOption]
}

struct NotionSelectOption: Codable {
    let id: String?
    let name: String
    let color: String?
}

// MARK: - Query Response (POST /v1/databases/{id}/query)

struct NotionQueryResponse: Decodable {
    let results: [NotionPage]
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct NotionPage: Decodable {
    let id: String
    let properties: [String: NotionPropertyValue]
}

struct NotionPropertyValue: Decodable {
    let type: String
    let title: [NotionRichText]?
    let number: Double?
    let date: NotionDateValue?
    let select: NotionSelectName?
    let richText: [NotionRichText]?

    enum CodingKeys: String, CodingKey {
        case type, title, number, date, select
        case richText = "rich_text"
    }

    var textValue: String? {
        (title ?? richText)?.first?.plainText
    }
}

struct NotionDateValue: Decodable {
    let start: String
}

struct NotionSelectName: Decodable {
    let name: String?
}

// MARK: - Create Page Response (POST /v1/pages)

struct NotionCreatePageResponse: Decodable {
    let id: String
}

// MARK: - Database Response (POST /v1/databases, GET /v1/databases/{id})

struct NotionDatabaseResponse: Decodable {
    let id: String
    let title: [NotionRichText]
    let url: String?
}
