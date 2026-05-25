import BackgroundTasks
import SwiftData
import SwiftUI

@main
struct FinotionApp: App {
    private let appState: AppState
    private let notionService: any NotionService
    private let categoryService: CategoryService
    private let syncService: any SyncServiceProtocol
    private let dispatchService: RecurringDispatchService
    private let modelContainer: ModelContainer

    init() {
        let kvStore = iCloudKVStoreService()
        #if DEBUG
        let notion: any NotionService = MockNotionService()
        #else
        let notion: any NotionService = LiveNotionService(
            keychainService: KeychainService(),
            fieldMappingProvider: { kvStore.load() }
        )
        #endif
        self.notionService = notion
        self.categoryService = CategoryService(notionService: notion)

        let state = AppState()
        state.resolveAuthStatus()
        self.appState = state

        let container: ModelContainer
        if let prod = try? DataContainer.makeContainer(inMemory: false) {
            container = prod
        } else if let fallback = try? DataContainer.makeContainer(inMemory: true) {
            container = fallback
        } else {
            fatalError("Failed to initialize ModelContainer")
        }
        self.modelContainer = container
        self.syncService = SyncService(notionService: notion, container: container)

        let dispatch = RecurringDispatchService(
            notionService: notion,
            container: container,
            fieldMappingProvider: { kvStore.load() }
        )

        self.dispatchService = dispatch

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.finotion.recurring-dispatch",
            using: nil
        ) { task in
            guard let bgTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await dispatch.handleBackgroundTask(bgTask)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.notionService, notionService)
                .environment(\.categoryService, categoryService)
                .environment(\.syncService, syncService)
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appState.authStatus {
            case .authenticated:
                MainTabView()
            case .unauthenticated, .unknown:
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NSUbiquitousKeyValueStore.default.synchronize()
                appState.reloadFieldMapping()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            )
        ) { _ in
            appState.reloadFieldMapping()
        }
        .onOpenURL { url in
            guard let intent = URLSchemeHandler.parse(url) else { return }
            appState.pendingIntent = intent
        }
    }
}
