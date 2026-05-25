import XCTest
@testable import Finotion

final class KeychainServiceTests: XCTestCase {

    // MARK: - FieldMapping Codable + Equatable

    func testFieldMappingCodableWithAllFields() throws {
        let mapping = FieldMapping(
            databaseId: "db-123",
            nameField: "Nome",
            amountField: "Valor",
            dateField: "Data",
            typeField: "Tipo",
            categoryField: "Categoria",
            paymentMethodField: "Método",
            refDateField: "Data Ref"
        )
        let decoded = try JSONDecoder().decode(FieldMapping.self, from: JSONEncoder().encode(mapping))
        XCTAssertEqual(decoded, mapping)
        XCTAssertEqual(decoded.typeField, "Tipo")
        XCTAssertEqual(decoded.refDateField, "Data Ref")
    }

    func testFieldMappingCodableWithNilOptionals() throws {
        let mapping = FieldMapping(databaseId: "db-456", nameField: "Name", amountField: "Amount", dateField: "Date")
        let decoded = try JSONDecoder().decode(FieldMapping.self, from: JSONEncoder().encode(mapping))
        XCTAssertEqual(decoded, mapping)
        XCTAssertNil(decoded.typeField)
        XCTAssertNil(decoded.categoryField)
        XCTAssertNil(decoded.paymentMethodField)
        XCTAssertNil(decoded.refDateField)
    }

    func testFieldMappingEquatable() {
        let a = FieldMapping(databaseId: "db", nameField: "n", amountField: "a", dateField: "d")
        let b = FieldMapping(databaseId: "db", nameField: "n", amountField: "a", dateField: "d")
        let c = FieldMapping(databaseId: "db-different", nameField: "n", amountField: "a", dateField: "d")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - MockKeychainService

    func testMockKeychainSaveAndLoad() throws {
        let service = MockKeychainService()
        try service.save(token: "notion-token-abc")
        XCTAssertEqual(service.loadToken(), "notion-token-abc")
    }

    func testMockKeychainDeleteClearsToken() throws {
        let service = MockKeychainService()
        try service.save(token: "notion-token-abc")
        service.deleteToken()
        XCTAssertNil(service.loadToken())
    }

    func testMockKeychainLoadReturnsNilInitially() {
        XCTAssertNil(MockKeychainService().loadToken())
    }

    func testMockKeychainThrowsWhenConfigured() {
        let service = MockKeychainService()
        service.shouldThrowOnSave = true
        XCTAssertThrowsError(try service.save(token: "token"))
    }

    func testMockKeychainConformsToProtocol() {
        let service: any KeychainServiceProtocol = MockKeychainService()
        XCTAssertNotNil(service)
    }

    // MARK: - MockiCloudKVStoreService

    func testMockKVStoreSaveAndLoad() throws {
        let service = MockiCloudKVStoreService()
        let mapping = FieldMapping(databaseId: "db", nameField: "n", amountField: "a", dateField: "d")
        try service.save(mapping)
        XCTAssertEqual(service.load(), mapping)
    }

    func testMockKVStoreClearMakesLoadReturnNil() throws {
        let service = MockiCloudKVStoreService()
        let mapping = FieldMapping(databaseId: "db", nameField: "n", amountField: "a", dateField: "d")
        try service.save(mapping)
        service.clear()
        XCTAssertNil(service.load())
    }

    func testMockKVStoreCorruptedDataReturnsNilWithoutCrash() {
        let service = MockiCloudKVStoreService()
        service.setCorruptedData()
        XCTAssertNil(service.load())
    }

    func testMockKVStoreLoadReturnsNilInitially() {
        XCTAssertNil(MockiCloudKVStoreService().load())
    }

    func testMockKVStoreConformsToProtocol() {
        let service: any iCloudKVStoreServiceProtocol = MockiCloudKVStoreService()
        XCTAssertNotNil(service)
    }
}
