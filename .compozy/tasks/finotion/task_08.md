---
status: completed
title: SyncService and Offline Write Queue
type: backend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 8: SyncService and Offline Write Queue

## Overview
Implements the offline resilience layer that ensures no transaction is lost when Notion is unreachable. `SyncService` monitors network connectivity via `NWPathMonitor`, manages the `PendingEntry` SwiftData queue, and flushes it with exponential back-off when connectivity is restored. Idempotency via the `Transaction.id` key prevents duplicates on retry.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `SyncService` as an `@Observable` class with `enqueue(_ entry: PendingEntry)`, `flush() async`, and a `pendingCount: Int` computed property.
- MUST start a `NWPathMonitor` on init; when the path transitions to `.satisfied`, MUST call `flush()` automatically.
- `flush()` MUST process `PendingEntry` records in `createdAt` ascending order (oldest first), respecting the exponential back-off delay before each retry attempt.
- Back-off schedule: attempt 1 = immediate, attempt 2 = 30 s, attempt 3 = 2 min, attempt 4 = 10 min, attempt 5 = 30 min. After 5 failed attempts, set `status = "failed"` and stop retrying.
- MUST check `lastAttemptAt` to respect the back-off window — skip entries whose next eligible time has not arrived.
- On a successful Notion call, MUST set `PendingEntry.status = "synced"` and delete the record from SwiftData.
- MUST implement idempotency deduplication: before posting, check whether a Notion page already exists with the `Transaction.id` embedded in the Description field; if found, mark the entry `"synced"` without re-posting.
- MUST handle `NotionError.rateLimited` by pausing the flush loop for 2 seconds and retrying the same entry once before incrementing `retryCount`.
- MUST NOT retain a strong reference to the SwiftData `ModelContext` across `async` suspension points — fetch, mutate, and save within a single synchronous context access.
- Both `SyncService` and its protocol MUST be injectable to allow mock implementations in tests.
</requirements>

## Subtasks
- [x] 8.1 Create `Services/Sync/SyncServiceProtocol.swift` and `Services/Sync/SyncService.swift` with `enqueue`, `flush`, `pendingCount`, and `NWPathMonitor` wiring.
- [x] 8.2 Implement the flush loop: fetch pending entries, apply back-off window check, decode `transactionData`, call `NotionService.createTransaction`, handle success/failure/rate-limit.
- [x] 8.3 Implement idempotency deduplication: before `createTransaction`, call `NotionService.queryTransactions` with a Description filter for the `Transaction.id` string; if found, mark synced without posting.
- [x] 8.4 Create `Services/Sync/MockSyncService.swift` for use in `ExpenseEntryViewModel` tests (task_07).
- [x] 8.5 Write unit tests for `SyncService` back-off, retry, idempotency, and rate-limit handling.

## Implementation Details
See TechSpec "Integration Points — Notion API" for the retry strategy and TechSpec "Data Models — SwiftData Models" for the `PendingEntry` fields.

The idempotency key (`Transaction.id` as a UUID string) is written into the Notion Description field during `createTransaction`. On retry, `queryTransactions` filters by that string. This means `LiveNotionService.createTransaction` MUST always append the id string to the Description — not optional. The format is: `[pendingId:{uuid}]` appended after any user-provided description text.

The `NWPathMonitor` MUST run on a dedicated `DispatchQueue` (not the main queue). The flush trigger `Task { await flush() }` posts to the Swift concurrency runtime from the monitor callback.

### Relevant Files
- `Finotion/Services/Sync/SyncService.swift` — offline queue manager (to create)
- `Finotion/Services/Sync/SyncServiceProtocol.swift` — injectable protocol (to create)
- `Finotion/Services/Sync/MockSyncService.swift` — test mock (to create)
- `FinotionTests/Services/SyncServiceTests.swift` — unit tests (to create)

### Dependent Files
- `task_02` (`NotionService`, `MockNotionService`) — `createTransaction` and `queryTransactions` called during flush.
- `task_03` (`PendingEntry`, SwiftData container) — `SyncService` reads and writes `PendingEntry` records.
- `task_07` (`ExpenseEntryViewModel`) — calls `SyncService.enqueue` when `NotionService.createTransaction` fails.
- `task_05` (`AppState` DI root) — `SyncService` injected into environment alongside other services.

### Related ADRs
- [ADR-004: Offline Write Queue with Auto-Retry](../adrs/adr-004.md) — `PendingEntry` model and NWPathMonitor strategy originate from this decision.

## Deliverables
- `Services/Sync/SyncService.swift` and `SyncServiceProtocol.swift`.
- `Services/Sync/MockSyncService.swift` for dependent task tests.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `SyncService.enqueue(_:)` inserts a `PendingEntry` with `status = "pending"` and `retryCount = 0` into the in-memory container.
  - [ ] `flush()` calls `MockNotionService.createTransaction` for a pending entry and sets `status = "synced"` on success.
  - [ ] `flush()` increments `retryCount` and updates `lastAttemptAt` when `MockNotionService.createTransaction` throws `NotionError.serverError(500)`.
  - [ ] An entry with `retryCount = 4` and a failed attempt is set to `status = "failed"` on the next failure (max attempts reached).
  - [ ] Back-off window respected: an entry with `lastAttemptAt` 10 seconds ago and `retryCount = 1` (30 s window) is skipped by `flush()`.
  - [ ] `flush()` handles `NotionError.rateLimited` by pausing 2 seconds and retrying the same entry once (mock time control or fast-clock injection).
  - [ ] Idempotency: when `MockNotionService.queryTransactions` returns a transaction whose description contains the matching `pendingId`, `flush()` marks the entry `"synced"` without calling `createTransaction`.
  - [ ] `pendingCount` returns the number of entries with `status == "pending"` or `"failed"`.
- Integration tests:
  - [ ] `NWPathMonitor` path change to `.satisfied` triggers `flush()` (use a test double that records flush calls).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- A transaction saved while offline (no connectivity) appears in Notion within 30 seconds of connectivity being restored.
- Entries are never duplicated in Notion — submitting the same `Transaction.id` twice results in exactly one Notion page.
- After 5 failed attempts, `PendingEntry.status == "failed"` and the entry is no longer retried automatically.
