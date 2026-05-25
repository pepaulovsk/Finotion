import Foundation

final class MockSyncService: SyncServiceProtocol, @unchecked Sendable {
    private(set) var enqueuedEntries: [PendingEntry] = []
    private(set) var flushCallCount = 0

    var pendingCount: Int { enqueuedEntries.filter { $0.status == "pending" }.count }

    func enqueue(_ entry: PendingEntry) async {
        enqueuedEntries.append(entry)
    }

    func flush() async {
        flushCallCount += 1
    }
}
