import XCTest
@testable import Finotion

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private var mockNotion: MockNotionService!
    private var mockKeychain: MockKeychainService!
    private var mockKVStore: MockiCloudKVStoreService!
    private var appState: AppState!
    private var vm: OnboardingViewModel!

    override func setUp() {
        super.setUp()
        mockNotion = MockNotionService()
        mockKeychain = MockKeychainService()
        mockKVStore = MockiCloudKVStoreService()
        appState = AppState(keychainService: mockKeychain, kvStoreService: mockKVStore)
        vm = OnboardingViewModel(notionService: mockNotion, appState: appState)
    }

    // MARK: - Step progression

    func testInitialStepIsConnectNotion() {
        XCTAssertEqual(vm.step, .connectNotion)
    }

    func testCompleteOAuthAdvancesToChooseDatabase() {
        vm.completeOAuth(token: "tok-123")
        XCTAssertEqual(vm.step, .chooseDatabase)
    }

    // MARK: - Path A

    func testPathACallsCreateDatabaseAndAdvancesToInstallShortcut() async throws {
        vm.completeOAuth(token: "tok-123")
        await vm.selectPathA()
        XCTAssertEqual(vm.step, .installShortcut)
        XCTAssertNil(vm.error)
    }

    func testPathANetworkErrorSetsError() async {
        mockNotion.createDatabaseError = .serverError(500)
        vm.completeOAuth(token: "tok-123")
        await vm.selectPathA()
        XCTAssertEqual(vm.error, .networkError)
        XCTAssertEqual(vm.step, .chooseDatabase)
    }

    // MARK: - Path B

    func testPathBSelectDatabaseFetchesPropertiesAndAdvancesToFieldMapping() async throws {
        let db = NotionDatabase(id: "db-1", title: "Finances")
        mockNotion = MockNotionService(
            databases: [db],
            propertiesByDatabase: ["db-1": .templateProperties]
        )
        vm = OnboardingViewModel(notionService: mockNotion, appState: appState)
        vm.completeOAuth(token: "tok-123")
        await vm.selectPathBDatabase(db)
        XCTAssertEqual(vm.step, .fieldMapping)
        XCTAssertFalse(vm.databaseProperties.isEmpty)
    }

    func testConfirmFieldMappingWithAllRequiredFieldsAdvancesToInstallShortcut() async throws {
        let db = NotionDatabase(id: "db-1", title: "Finances")
        mockNotion = MockNotionService(
            databases: [db],
            propertiesByDatabase: ["db-1": .templateProperties]
        )
        vm = OnboardingViewModel(notionService: mockNotion, appState: appState)
        vm.completeOAuth(token: "tok-123")
        await vm.selectPathBDatabase(db)

        vm.nameField = "Name"
        vm.amountField = "Amount"
        vm.dateField = "Date"
        vm.confirmFieldMapping()

        XCTAssertEqual(vm.step, .installShortcut)
        XCTAssertNil(vm.error)
    }

    func testConfirmFieldMappingWithMissingAmountFieldSetsValidationError() async throws {
        let db = NotionDatabase(id: "db-1", title: "Finances")
        mockNotion = MockNotionService(
            databases: [db],
            propertiesByDatabase: ["db-1": .templateProperties]
        )
        vm = OnboardingViewModel(notionService: mockNotion, appState: appState)
        vm.completeOAuth(token: "tok-123")
        await vm.selectPathBDatabase(db)

        vm.nameField = "Name"
        vm.amountField = ""
        vm.dateField = "Date"
        vm.confirmFieldMapping()

        XCTAssertEqual(vm.error, .fieldMappingIncomplete)
        XCTAssertEqual(vm.step, .fieldMapping)
    }

    // MARK: - OAuth errors

    func testOAuthCallbackWithNilURLSetsOAuthCancelledError() async {
        await vm.handleOAuthCallback(nil)
        XCTAssertEqual(vm.error, .oauthCancelled)
    }

    func testOAuthCallbackWithMissingCodeSetsOAuthFailedError() async {
        let url = URL(string: "finotion://oauth?error=access_denied")!
        await vm.handleOAuthCallback(url)
        XCTAssertEqual(vm.error, .oauthFailed("Missing code in callback"))
    }

    // MARK: - Shortcut step

    func testSkipShortcutAdvancesToNotificationPermission() {
        vm.completeOAuth(token: "tok-123")
        vm.skipShortcut()
        XCTAssertEqual(vm.step, .notificationPermission)
    }

    func testCompleteShortcutInstallAdvancesToNotificationPermission() {
        vm.completeOAuth(token: "tok-123")
        vm.completeShortcutInstall()
        XCTAssertEqual(vm.step, .notificationPermission)
    }

    // MARK: - Finalize

    func testSkipNotificationsSavesTokenAndMappingAndSetsAuthenticated() async throws {
        vm.completeOAuth(token: "tok-abc")
        await vm.selectPathA()
        vm.skipShortcut()
        vm.skipNotifications()

        XCTAssertEqual(mockKeychain.loadToken(), "tok-abc")
        XCTAssertNotNil(mockKVStore.load())
        XCTAssertEqual(appState.authStatus, .authenticated)
    }
}
