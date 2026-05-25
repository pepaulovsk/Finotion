import Foundation
import XCTest
@testable import Finotion

// MARK: - MockURLSession

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    struct Response {
        let data: Data
        let statusCode: Int
        let error: Error?

        init(data: Data = Data(), statusCode: Int = 200, error: Error? = nil) {
            self.data = data
            self.statusCode = statusCode
            self.error = error
        }
    }

    var responses: [Response] = []
    private(set) var capturedRequests: [URLRequest] = []
    private var callIndex = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        let response: Response
        if responses.isEmpty {
            response = Response()
        } else {
            response = responses[min(callIndex, responses.count - 1)]
        }
        callIndex += 1
        if let error = response.error { throw error }
        let url = request.url ?? URL(string: "https://api.notion.com")!
        let http = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        return (response.data, http)
    }

    func queue(statusCode: Int, json: Any) {
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        responses.append(Response(data: data, statusCode: statusCode))
    }

    func queueError(_ error: Error) {
        responses.append(Response(error: error))
    }
}

// MARK: - LiveNotionServiceTests

@MainActor
final class LiveNotionServiceTests: XCTestCase {

    private var mockSession: MockURLSession!
    private var mockKeychain: MockKeychainService!

    private let mapping = FieldMapping(
        databaseId: "db-1",
        nameField: "Name",
        amountField: "Amount",
        dateField: "Date"
    )

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychain = MockKeychainService()
        try? mockKeychain.save(token: "test-token")
    }

    private func makeService(rateLimitRetryDelay: TimeInterval = 0) -> LiveNotionService {
        LiveNotionService(
            keychainService: mockKeychain,
            fieldMappingProvider: { [mapping] in mapping },
            session: mockSession,
            rateLimitRetryDelay: rateLimitRetryDelay
        )
    }

    // MARK: - Error Mapping

    func test401ResponseThrowsUnauthorized() async {
        mockSession.queue(statusCode: 401, json: ["message": "Unauthorized"])
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test429ResponseRetriesOnceThenThrowsRateLimited() async {
        mockSession.queue(statusCode: 429, json: [:])
        mockSession.queue(statusCode: 429, json: [:])
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            XCTAssertEqual(error, .rateLimited)
            XCTAssertEqual(mockSession.capturedRequests.count, 2)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test429ResponseRetriesOnceAndSucceeds() async throws {
        mockSession.queue(statusCode: 429, json: [:])
        mockSession.queue(statusCode: 200, json: ["results": [Any]()])
        let svc = makeService()
        let databases = try await svc.fetchDatabases()
        XCTAssertEqual(databases.count, 0)
        XCTAssertEqual(mockSession.capturedRequests.count, 2)
    }

    func test500ResponseThrowsServerError() async {
        mockSession.queue(statusCode: 500, json: [:])
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            XCTAssertEqual(error, .serverError(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMalformedJSONThrowsDecodingError() async {
        mockSession.responses = [MockURLSession.Response(data: Data("not-json".utf8), statusCode: 200)]
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            if case .decodingError = error { return }
            XCTFail("Expected .decodingError, got \(error)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testURLErrorThrowsNetworkError() async {
        mockSession.queueError(URLError(.notConnectedToInternet))
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            XCTAssertEqual(error, .networkError(URLError(.notConnectedToInternet)))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Headers

    func testEveryRequestIncludesAuthorizationBearerHeader() async throws {
        mockSession.queue(statusCode: 200, json: ["results": [Any]()])
        let svc = makeService()
        _ = try await svc.fetchDatabases()
        let authHeader = mockSession.capturedRequests.first?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer test-token")
    }

    func testEveryRequestIncludesNotionVersionHeader() async throws {
        mockSession.queue(statusCode: 200, json: ["results": [Any]()])
        let svc = makeService()
        _ = try await svc.fetchDatabases()
        let versionHeader = mockSession.capturedRequests.first?.value(forHTTPHeaderField: "Notion-Version")
        XCTAssertEqual(versionHeader, "2022-06-28")
    }

    // MARK: - Token

    func testNilTokenThrowsUnauthorizedBeforeNetworkCall() async {
        mockKeychain.deleteToken()
        let svc = makeService()
        do {
            _ = try await svc.fetchDatabases()
            XCTFail("Expected throw")
        } catch let error as NotionError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertTrue(mockSession.capturedRequests.isEmpty)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - createTransaction pendingId

    func testCreateTransactionAppendsPendingIdToDescription() async throws {
        mockSession.queue(statusCode: 200, json: ["id": "page-123"])
        let svc = makeService()
        let tx = Transaction(name: "Test", amount: 10, description: "My purchase")
        _ = try await svc.createTransaction(tx, databaseId: "db-1")

        guard let requestBody = mockSession.capturedRequests.first?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any],
              let props = json["properties"] as? [String: Any],
              let descProp = props["Descrição"] as? [String: Any],
              let richText = descProp["rich_text"] as? [[String: Any]],
              let content = (richText.first?["text"] as? [String: Any])?["content"] as? String else {
            XCTFail("Could not parse request body")
            return
        }
        XCTAssertTrue(content.contains("[pendingId:\(tx.id.uuidString)]"), "Missing pendingId tag in: \(content)")
        XCTAssertTrue(content.contains("My purchase"), "Missing user description in: \(content)")
    }

    func testCreateTransactionWithNilDescriptionWritesPendingIdOnly() async throws {
        mockSession.queue(statusCode: 200, json: ["id": "page-456"])
        let svc = makeService()
        let tx = Transaction(name: "NoDesc", amount: 5)
        _ = try await svc.createTransaction(tx, databaseId: "db-1")

        guard let requestBody = mockSession.capturedRequests.first?.httpBody,
              let json = try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any],
              let props = json["properties"] as? [String: Any],
              let descProp = props["Descrição"] as? [String: Any],
              let richText = descProp["rich_text"] as? [[String: Any]],
              let content = (richText.first?["text"] as? [String: Any])?["content"] as? String else {
            XCTFail("Could not parse request body")
            return
        }
        XCTAssertEqual(content, "[pendingId:\(tx.id.uuidString)]")
    }

    // MARK: - Rate limit spacing

    func testTwoConcurrentCallsAreSpacedAtLeast350ms() async throws {
        let successJSON: Any = ["results": [Any]()]
        mockSession.queue(statusCode: 200, json: successJSON)
        mockSession.queue(statusCode: 200, json: successJSON)
        let svc = makeService()

        let start = Date.now
        async let first = svc.fetchDatabases()
        async let second = svc.fetchDatabases()
        _ = try await (first, second)
        let elapsed = Date.now.timeIntervalSince(start)

        XCTAssertGreaterThanOrEqual(elapsed, 0.35, "Requests should be spaced at least 350ms apart")
    }

    // MARK: - Integration test stubs

    func testIntegrationFetchDatabasesReturnsAtLeastOne() async throws {
        try XCTSkip("Requires a real Notion sandbox token — run manually with NOTION_TOKEN env var")
    }

    func testIntegrationCreateTransactionAppearsInQuery() async throws {
        try XCTSkip("Requires a real Notion sandbox token — run manually with NOTION_TOKEN env var")
    }

    func testIntegrationAddCategoryOptionAppearsInProperties() async throws {
        try XCTSkip("Requires a real Notion sandbox token — run manually with NOTION_TOKEN env var")
    }
}
