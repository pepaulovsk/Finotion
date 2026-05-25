import Foundation
import Observation
import UserNotifications

enum OnboardingStep: Equatable {
    case connectNotion
    case chooseDatabase
    case fieldMapping
    case installShortcut
    case notificationPermission
}

enum OnboardingError: Error, Equatable {
    case oauthCancelled
    case oauthFailed(String)
    case networkError
    case fieldMappingIncomplete
}

@Observable
final class OnboardingViewModel {
    var step: OnboardingStep = .connectNotion
    var error: OnboardingError?
    var isLoading = false
    var databases: [NotionDatabase] = []
    var selectedDatabase: NotionDatabase?
    var databaseProperties: [NotionProperty] = []

    // Path B field assignments
    var nameField = ""
    var amountField = ""
    var dateField = ""
    var typeField = ""
    var categoryField = ""
    var paymentMethodField = ""
    var refDateField = ""

    private var pendingToken: String?
    private var pendingMapping: FieldMapping?

    private let notionService: any NotionService
    private let appState: AppState

    init(notionService: any NotionService, appState: AppState) {
        self.notionService = notionService
        self.appState = appState
    }

    // MARK: - Step 1: OAuth

    var notionAuthURL: URL? {
        // Credentials injected via build config in production; empty for MVP scaffold
        let clientId = Bundle.main.object(forInfoDictionaryKey: "NotionClientID") as? String ?? ""
        let redirect = "finotion://oauth"
        var components = URLComponents(string: "https://api.notion.com/v1/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "owner", value: "user"),
            URLQueryItem(name: "redirect_uri", value: redirect)
        ]
        return components?.url
    }

    func handleOAuthCallback(_ url: URL?) async {
        guard let url = url else {
            error = .oauthCancelled
            return
        }
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            error = .oauthFailed("Missing code in callback")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await exchangeCode(code)
            completeOAuth(token: token)
        } catch {
            self.error = .oauthFailed(error.localizedDescription)
        }
    }

    func completeOAuth(token: String) {
        pendingToken = token
        step = .chooseDatabase
    }

    // MARK: - Step 2: Database path

    func loadDatabases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            databases = try await notionService.fetchDatabases()
        } catch {
            self.error = .networkError
        }
    }

    func selectPathA() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let db = try await notionService.createDatabase(parentPageId: "")
            pendingMapping = FieldMapping(
                databaseId: db.id,
                nameField: "Nome",
                amountField: "Valor",
                dateField: "Data",
                typeField: "Tipo",
                categoryField: "Categoria",
                paymentMethodField: "Método",
                refDateField: "Data Referência"
            )
            step = .installShortcut
        } catch {
            self.error = .networkError
        }
    }

    func selectPathBDatabase(_ db: NotionDatabase) async {
        selectedDatabase = db
        isLoading = true
        defer { isLoading = false }
        do {
            databaseProperties = try await notionService.fetchDatabaseProperties(db.id)
            step = .fieldMapping
        } catch {
            self.error = .networkError
        }
    }

    func confirmFieldMapping() {
        guard !nameField.isEmpty, !amountField.isEmpty, !dateField.isEmpty,
              let db = selectedDatabase else {
            error = .fieldMappingIncomplete
            return
        }
        pendingMapping = FieldMapping(
            databaseId: db.id,
            nameField: nameField,
            amountField: amountField,
            dateField: dateField,
            typeField: typeField.isEmpty ? nil : typeField,
            categoryField: categoryField.isEmpty ? nil : categoryField,
            paymentMethodField: paymentMethodField.isEmpty ? nil : paymentMethodField,
            refDateField: refDateField.isEmpty ? nil : refDateField
        )
        step = .installShortcut
    }

    // MARK: - Step 3: Shortcut

    var shortcutInstallURL: URL? {
        URL(string: "shortcuts://import-shortcut?name=Register+Expense")
    }

    func skipShortcut() {
        step = .notificationPermission
    }

    func completeShortcutInstall() {
        step = .notificationPermission
    }

    // MARK: - Step 4: Notifications + finalize

    func skipNotifications() {
        finalize()
    }

    func completeNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        finalize()
    }

    // MARK: - Private

    private func finalize() {
        guard let token = pendingToken, let mapping = pendingMapping else { return }
        do {
            try appState.completeOnboarding(token: token, mapping: mapping)
        } catch {
            self.error = .oauthFailed(error.localizedDescription)
        }
    }

    private func exchangeCode(_ code: String) async throws -> String {
        // Token exchange — stubbed; LiveNotionService (task_12) owns the real URLSession layer.
        // In tests, completeOAuth(token:) is called directly instead of going through OAuth.
        guard let url = URL(string: "https://api.notion.com/v1/oauth/token") else {
            throw OnboardingError.oauthFailed("Invalid token endpoint")
        }
        let clientId = Bundle.main.object(forInfoDictionaryKey: "NotionClientID") as? String ?? ""
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "NotionClientSecret") as? String ?? ""
        let credentials = Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")

        let body = ["grant_type": "authorization_code", "code": code, "redirect_uri": "finotion://oauth"]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable { let access_token: String }
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return response.access_token
    }
}
