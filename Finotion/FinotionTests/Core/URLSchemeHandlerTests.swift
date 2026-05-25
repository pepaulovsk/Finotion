import XCTest
@testable import Finotion

final class URLSchemeHandlerTests: XCTestCase {

    func testParseFullURL() throws {
        let url = URL(string: "finotion://add?merchant=Padaria&amount=15.50&paymentMethod=credit")!
        let intent = try XCTUnwrap(URLSchemeHandler.parse(url))
        XCTAssertEqual(intent.merchant, "Padaria")
        XCTAssertEqual(intent.amount, 15.50)
        XCTAssertEqual(intent.paymentMethod, "credit")
    }

    func testParseNoParameters() throws {
        let url = URL(string: "finotion://add")!
        let intent = try XCTUnwrap(URLSchemeHandler.parse(url))
        XCTAssertNil(intent.merchant)
        XCTAssertNil(intent.amount)
        XCTAssertNil(intent.paymentMethod)
        XCTAssertNil(intent.date)
    }

    func testParseMalformedAmountReturnsNilAmount() throws {
        let url = URL(string: "finotion://add?amount=notanumber")!
        let intent = try XCTUnwrap(URLSchemeHandler.parse(url))
        XCTAssertNil(intent.amount)
    }

    func testParseValidISODate() throws {
        let url = URL(string: "finotion://add?date=2026-05-25T10:00:00Z")!
        let intent = try XCTUnwrap(URLSchemeHandler.parse(url))
        XCTAssertNotNil(intent.date)
    }

    func testParseWrongSchemeReturnsNil() {
        let url = URL(string: "https://finotion.app/add?merchant=Test")!
        XCTAssertNil(URLSchemeHandler.parse(url))
    }

    func testParseWrongHostReturnsNil() {
        let url = URL(string: "finotion://dashboard")!
        XCTAssertNil(URLSchemeHandler.parse(url))
    }

    func testParseEmptyMerchantTreatedAsNil() throws {
        let url = URL(string: "finotion://add?merchant=")!
        let intent = try XCTUnwrap(URLSchemeHandler.parse(url))
        XCTAssertNil(intent.merchant)
    }
}
