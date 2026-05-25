import SwiftUI

private struct NotionServiceKey: EnvironmentKey {
    static let defaultValue: any NotionService = MockNotionService()
}

private struct CategoryServiceKey: EnvironmentKey {
    static let defaultValue: CategoryService = CategoryService(notionService: MockNotionService())
}

private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue: any SyncServiceProtocol = NullSyncService()
}

struct NullSyncService: SyncServiceProtocol, Sendable {
    var pendingCount: Int { 0 }
    func enqueue(_ entry: PendingEntry) async {}
    func flush() async {}
}

extension EnvironmentValues {
    var notionService: any NotionService {
        get { self[NotionServiceKey.self] }
        set { self[NotionServiceKey.self] = newValue }
    }

    var categoryService: CategoryService {
        get { self[CategoryServiceKey.self] }
        set { self[CategoryServiceKey.self] = newValue }
    }

    var syncService: any SyncServiceProtocol {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}
