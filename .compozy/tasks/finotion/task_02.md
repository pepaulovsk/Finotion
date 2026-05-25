---
status: pending
title: NotionService Protocol, Domain Types and MockNotionService
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 2: NotionService Protocol, Domain Types and MockNotionService

## Overview
Defines the contract for all Notion API interactions through a `NotionService` protocol and the domain model types the entire app depends on. Implements a full `MockNotionService` so every subsequent feature task can be built and tested without a real Notion account. This is the most widely depended-upon task in the project — every feature module uses these types.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST define the `NotionService` protocol exactly as specified in the TechSpec "Core Interfaces" section, with all six methods using Swift concurrency (`async throws`).
- MUST define domain types: `Transaction`, `TransactionType`, `NotionDatabase`, `NotionProperty`, `NotionFilter`, and `NotionError`.
- `Transaction` MUST include an `id: UUID` field used as the idempotency key for offline queue deduplication (see TechSpec ADR-004 notes).
- `NotionError` MUST be an enum covering `.unauthorized`, `.rateLimited`, `.serverError(Int)`, `.networkError(URLError)`, `.decodingError(Error)`.
- MUST implement `MockNotionService` with configurable in-memory state (seed transactions, databases, properties) and controllable failure injection for each method.
- The mock MUST be usable in SwiftUI Previews via a static `preview` factory property.
- MUST NOT contain any URLSession or networking code — that belongs in task_12.
</requirements>

## Subtasks
- [ ] 2.1 Create `Services/Notion/NotionService.swift` with the `NotionService` protocol and all domain types (`Transaction`, `NotionDatabase`, `NotionProperty`, `NotionFilter`, `NotionError`, `TransactionType`).
- [ ] 2.2 Create `Services/Notion/MockNotionService.swift` implementing `NotionService` with in-memory state and per-method failure injection.
- [ ] 2.3 Add a static `MockNotionService.preview` property pre-seeded with realistic sample transactions and databases for use in SwiftUI Previews.
- [ ] 2.4 Write unit tests covering all mock method behaviors: happy path, failure injection, and empty-state edge cases.

## Implementation Details
See TechSpec "Core Interfaces" section for the exact protocol signature and "Data Models — Transaction" for the `Transaction` struct fields.

The `MockNotionService` should store its state in arrays/dictionaries and update them when `createTransaction` is called, so tests can verify state after calling write methods.

### Relevant Files
- `Finotion/Services/Notion/NotionService.swift` — protocol + domain types (to create)
- `Finotion/Services/Notion/MockNotionService.swift` — mock implementation (to create)
- `FinotionTests/Services/NotionServiceTests.swift` — unit tests (to create)

### Dependent Files
- All feature ViewModels in tasks 06–11 will import and depend on `NotionService`.
- `task_05` (AppState) injects `NotionService` into the SwiftUI Environment.
- `task_08` (SyncService) calls `NotionService.createTransaction` during queue flush.
- `task_12` (LiveNotionService) will conform to this protocol.

### Related ADRs
- [ADR-005: NotionService Protocol](../adrs/adr-005.md) — Rationale for protocol-backed abstraction over third-party SDKs.
- [ADR-004: Offline Write Queue](../adrs/adr-004.md) — The `Transaction.id` field serves as the idempotency key for the retry queue.

## Deliverables
- `Services/Notion/NotionService.swift` — protocol and all domain types.
- `Services/Notion/MockNotionService.swift` — full mock with failure injection.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for mock state transitions **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `MockNotionService.fetchDatabases()` returns the seeded databases.
  - [ ] `MockNotionService.createTransaction(_:databaseId:)` adds the transaction to in-memory state and is retrievable via `queryTransactions`.
  - [ ] `MockNotionService.createTransaction` with failure injection throws `NotionError.serverError(500)`.
  - [ ] `MockNotionService.fetchDatabaseProperties(_:)` with an unknown database ID throws `NotionError.serverError(404)`.
  - [ ] `NotionError` cases are correctly equatable for use in assertions.
  - [ ] `Transaction` encodes and decodes via `Codable` with no data loss (all optional fields preserved).
- Integration tests:
  - [ ] `MockNotionService.preview` can be injected into a SwiftUI Preview without compile errors.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `MockNotionService` allows all feature tasks (06–11) to be developed and tested without a real Notion token.
- The protocol compiles without warnings and is fully `Sendable`-conformant for use across async contexts.
