protocol SyncServiceProtocol: Sendable {
    var pendingCount: Int { get }
    func enqueue(_ entry: PendingEntry) async
    func flush() async
}
