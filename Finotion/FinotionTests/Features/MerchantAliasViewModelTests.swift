import Foundation
import SwiftData
import XCTest
@testable import Finotion

@MainActor
final class MerchantAliasViewModelTests: XCTestCase {

    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = try DataContainer.makeContainer(inMemory: true)
    }

    // MARK: - Helpers

    private func insert(_ alias: MerchantAlias) {
        let context = ModelContext(container)
        context.insert(alias)
        try? context.save()
    }

    // MARK: - fetchAll splits records

    func testFetchAllSplitsUnnamedAndNamed() throws {
        insert(MerchantAlias(rawName: "STORE A"))
        insert(MerchantAlias(rawName: "STORE B", alias: "Store B"))

        let vm = MerchantAliasViewModel(context: ModelContext(container))

        XCTAssertEqual(vm.unnamed.count, 1)
        XCTAssertEqual(vm.named.count, 1)
        XCTAssertEqual(vm.unnamed.first?.rawName, "STORE A")
        XCTAssertEqual(vm.named.first?.alias, "Store B")
    }

    // MARK: - setAlias

    func testSetAliasMovesMerchantToNamedSection() throws {
        insert(MerchantAlias(rawName: "RENATA PASCOLLI SOUSA"))

        let vm = MerchantAliasViewModel(context: ModelContext(container))
        XCTAssertEqual(vm.unnamed.count, 1)

        vm.setAlias("Padaria da Renata", for: "RENATA PASCOLLI SOUSA")

        XCTAssertTrue(vm.unnamed.isEmpty)
        XCTAssertEqual(vm.named.count, 1)
        XCTAssertEqual(vm.named.first?.alias, "Padaria da Renata")
    }

    // MARK: - clearAlias

    func testClearAliasSetsNilAndMovesBackToUnnamed() throws {
        insert(MerchantAlias(rawName: "RENATA PASCOLLI SOUSA", alias: "Padaria da Renata"))

        let vm = MerchantAliasViewModel(context: ModelContext(container))
        XCTAssertEqual(vm.named.count, 1)

        vm.clearAlias(for: "RENATA PASCOLLI SOUSA")

        XCTAssertTrue(vm.named.isEmpty)
        XCTAssertEqual(vm.unnamed.count, 1)

        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<MerchantAlias>())
        XCTAssertEqual(all.count, 1)
        XCTAssertNil(all.first?.alias)
    }

    // MARK: - Sorting

    func testUnnamedSortedBySeenAtDescendingAndNamedSortedAlphabetically() throws {
        let earlier = Date(timeIntervalSinceNow: -3600)
        let later = Date(timeIntervalSinceNow: -60)
        insert(MerchantAlias(rawName: "STORE A", seenAt: earlier))
        insert(MerchantAlias(rawName: "STORE B", seenAt: later))
        insert(MerchantAlias(rawName: "STORE C", alias: "Zebra Store"))
        insert(MerchantAlias(rawName: "STORE D", alias: "Apple Store"))

        let vm = MerchantAliasViewModel(context: ModelContext(container))

        XCTAssertEqual(vm.unnamed.count, 2)
        XCTAssertEqual(vm.unnamed.first?.rawName, "STORE B")

        XCTAssertEqual(vm.named.count, 2)
        XCTAssertEqual(vm.named.first?.alias, "Apple Store")
    }

    // MARK: - AppState.signOut

    func testSignOutClearsKeychainToken() throws {
        let keychain = MockKeychainService()
        try keychain.save(token: "some-token")
        let kvStore = MockiCloudKVStoreService()
        let state = AppState(keychainService: keychain, kvStoreService: kvStore)

        state.signOut()

        XCTAssertNil(keychain.loadToken())
    }

    func testSignOutClearsFieldMappingFromKVStore() throws {
        let keychain = MockKeychainService()
        let kvStore = MockiCloudKVStoreService()
        try kvStore.save(FieldMapping(databaseId: "db-1", nameField: "Name", amountField: "Amount", dateField: "Date"))
        let state = AppState(keychainService: keychain, kvStoreService: kvStore)

        state.signOut()

        XCTAssertNil(kvStore.load())
    }

    func testSignOutSetsAuthStatusToUnauthenticated() throws {
        let keychain = MockKeychainService()
        try keychain.save(token: "some-token")
        let kvStore = MockiCloudKVStoreService()
        try kvStore.save(FieldMapping(databaseId: "db-1", nameField: "Name", amountField: "Amount", dateField: "Date"))
        let state = AppState(keychainService: keychain, kvStoreService: kvStore)
        state.resolveAuthStatus()
        XCTAssertEqual(state.authStatus, .authenticated)

        state.signOut()

        XCTAssertEqual(state.authStatus, .unauthenticated)
    }
}
