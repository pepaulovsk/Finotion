import Foundation
import Network
import Observation
import SwiftData

@Observable
final class SyncService: SyncServiceProtocol, @unchecked Sendable {
    private(set) var pendingCount: Int = 0

    var rateLimitDelay: TimeInterval = 2.0

    private let notionService: any NotionService
    private let container: ModelContainer
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.finotion.sync.network", qos: .utility)

    init(notionService: any NotionService, container: ModelContainer) {
        self.notionService = notionService
        self.container = container
        setupMonitor()
        Task { await refreshPendingCount() }
    }

    deinit { monitor.cancel() }

    // MARK: - SyncServiceProtocol

    func enqueue(_ entry: PendingEntry) async {
        let context = ModelContext(container)
        context.insert(entry)
        try? context.save()
        await refreshPendingCount()
    }

    func flush() async {
        let ids = fetchPendingIDs()
        for id in ids {
            await processEntry(id: id)
        }
        await refreshPendingCount()
    }

    // MARK: - Private

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { await self?.flush() }
        }
        monitor.start(queue: monitorQueue)
    }

    private func fetchPendingIDs() -> [UUID] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PendingEntry>(
            predicate: #Predicate { $0.status == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor))?.map(\.id) ?? []
    }

    private func processEntry(id: UUID) async {
        let context = ModelContext(container)
        let targetId = id
        let descriptor = FetchDescriptor<PendingEntry>(
            predicate: #Predicate { $0.id == targetId }
        )
        guard let entry = (try? context.fetch(descriptor))?.first else { return }

        // Back-off window check
        if let last = entry.lastAttemptAt {
            let delay = backoffSeconds(forRetryCount: entry.retryCount)
            guard -last.timeIntervalSinceNow >= delay else { return }
        }

        // Decode payload
        guard let payload = try? JSONDecoder().decode(PendingTransactionPayload.self, from: entry.transactionData) else {
            entry.status = "failed"
            try? context.save()
            return
        }

        let tx = payload.transaction
        let databaseId = payload.databaseId

        // Idempotency check
        let idempotencyFilter = NotionFilter(pendingId: tx.id.uuidString)
        let existing = (try? await notionService.queryTransactions(databaseId: databaseId, filter: idempotencyFilter)) ?? []
        if !existing.isEmpty {
            entry.status = "synced"
            context.delete(entry)
            try? context.save()
            return
        }

        // Attempt to post, with one rate-limit retry
        var rateLimitRetried = false
        while true {
            do {
                _ = try await notionService.createTransaction(tx, databaseId: databaseId)
                entry.status = "synced"
                context.delete(entry)
                try? context.save()
                return
            } catch NotionError.rateLimited {
                if rateLimitRetried {
                    markRetryOrFail(entry: entry, context: context)
                    return
                }
                try? await Task.sleep(for: .seconds(rateLimitDelay))
                rateLimitRetried = true
            } catch {
                markRetryOrFail(entry: entry, context: context)
                return
            }
        }
    }

    private func markRetryOrFail(entry: PendingEntry, context: ModelContext) {
        if entry.retryCount >= 4 {
            entry.status = "failed"
        } else {
            entry.retryCount += 1
            entry.lastAttemptAt = .now
        }
        try? context.save()
    }

    private func backoffSeconds(forRetryCount count: Int) -> TimeInterval {
        switch count {
        case 0: return 0
        case 1: return 30
        case 2: return 120
        case 3: return 600
        case 4: return 1800
        default: return .infinity
        }
    }

    private func refreshPendingCount() async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PendingEntry>(
            predicate: #Predicate { $0.status == "pending" || $0.status == "failed" }
        )
        pendingCount = (try? context.fetch(descriptor))?.count ?? 0
    }
}
