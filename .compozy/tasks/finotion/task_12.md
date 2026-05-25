---
status: pending
title: LiveNotionService URLSession Implementation
type: backend
complexity: high
dependencies:
  - task_02
  - task_04
---

# Task 12: LiveNotionService URLSession Implementation

## Overview
Implements the production `NotionService` that makes real HTTP calls to the Notion API using `URLSession`. This replaces the `MockNotionService` at the app's DI root for production builds. All feature tasks are built against the `NotionService` protocol, so this task can be delivered last without blocking any other feature work.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `LiveNotionService` conforming to `NotionService` using `URLSession.shared` (or an injected `URLSession` for testability).
- MUST read the Notion bearer token from `KeychainService.loadToken()` before each request; if `nil`, throw `NotionError.unauthorized`.
- MUST set the `Authorization: Bearer {token}` header and `Notion-Version: 2022-06-28` header on every request.
- MUST implement a serial async request queue with a minimum 350 ms interval between outgoing requests to respect Notion's 3 req/s rate limit.
- MUST map HTTP status codes to `NotionError`: 401 → `.unauthorized`, 429 → `.rateLimited`, 5xx → `.serverError(statusCode)`, decoding failure → `.decodingError(Error)`, `URLError` → `.networkError(URLError)`.
- MUST handle `NotionError.rateLimited` inline: wait 2 seconds and retry the request once before propagating the error.
- MUST implement `Codable` request and response types for all 7 Notion API endpoints consumed (see TechSpec "Notion API Endpoints Consumed").
- The `createTransaction` implementation MUST append `[pendingId:{transaction.id}]` to the Description field value so that `SyncService` can detect duplicates on retry.
- MUST implement OSLog structured logging: log each outgoing request URL and response status code (debug builds); log only outcomes (success/failure) in release builds; redact the token from all log output.
- MUST NOT store the token in any location other than Keychain — do NOT cache it in a property of `LiveNotionService`.
</requirements>

## Subtasks
- [ ] 12.1 Create `Services/Notion/Live/LiveNotionService.swift` as the production `NotionService` implementation.
- [ ] 12.2 Implement the serial request queue (actor or `AsyncStream`-based) enforcing 350 ms minimum request spacing.
- [ ] 12.3 Implement `Codable` request/response types for all Notion endpoints: `/v1/search`, `/v1/databases`, `/v1/databases/{id}`, `PATCH /v1/databases/{id}`, `/v1/databases/{id}/query`, `/v1/pages`, `/v1/users/me`.
- [ ] 12.4 Implement error mapping, rate-limit retry, and OSLog logging.
- [ ] 12.5 Wire `LiveNotionService` into `FinotionApp.swift` at the DI root for production builds; inject `MockNotionService` for `DEBUG` or preview builds.
- [ ] 12.6 Write unit tests for error mapping, rate-limit retry, and request header injection using a mock `URLSession`.
- [ ] 12.7 Write integration tests against the real Notion API using a sandbox integration token.

## Implementation Details
See TechSpec "Notion API Endpoints Consumed" for all endpoint URLs and their purpose. See TechSpec "Integration Points — Notion API" for the rate limiting, retry strategy, and auth pattern.

The request queue can be implemented as a Swift `actor` that tracks `lastRequestTime: Date` and `await Task.sleep` for the remaining interval before dispatching each request. All six `NotionService` methods enqueue through this actor, ensuring global 350 ms spacing even when called concurrently from multiple callers.

Notion API response shapes: the `/v1/databases/{id}/query` endpoint returns a `results` array of Page objects, each with a `properties` dictionary. The `LiveNotionService` resolves property values using the field names from `FieldMapping` — it must accept a `FieldMapping` parameter (or read it from an injected source) to know which property keys to read for `name`, `amount`, `date`, etc.

The `createTransaction` Description field value format: `{userDescription} [pendingId:{transaction.id.uuidString}]`. If `transaction.description` is `nil`, just write `[pendingId:{uuid}]`.

### Relevant Files
- `Finotion/Services/Notion/Live/LiveNotionService.swift` — production implementation (to create)
- `Finotion/Services/Notion/Live/NotionCodables.swift` — Notion request/response `Codable` types (to create)
- `Finotion/Services/Notion/Live/NotionRequestQueue.swift` — serial rate-limit queue actor (to create)
- `Finotion/FinotionApp.swift` — swap mock for live at DI root (to modify)
- `FinotionTests/Services/LiveNotionServiceTests.swift` — unit tests with mock URLSession (to create)

### Dependent Files
- `task_02` (`NotionService` protocol, `NotionError`, all domain types) — `LiveNotionService` conforms to this protocol.
- `task_04` (`KeychainService`) — token read on every request.
- All feature tasks (06–11) — will use `LiveNotionService` in production via the same `NotionService` protocol they were built against.

### Related ADRs
- [ADR-005: NotionService Protocol](../adrs/adr-005.md) — This task is the production fulfillment of the protocol-backed abstraction decision.
- [ADR-004: Offline Write Queue](../adrs/adr-004.md) — `createTransaction` must embed the `pendingId` so `SyncService` can deduplicate retries.

## Deliverables
- `Services/Notion/Live/LiveNotionService.swift` with all 6 protocol methods implemented.
- `Services/Notion/Live/NotionCodables.swift` with request/response types.
- `Services/Notion/Live/NotionRequestQueue.swift` (rate-limit actor).
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests against real Notion API **(REQUIRED)**

## Tests
- Unit tests (mock `URLSession`):
  - [ ] A 401 response from any endpoint throws `NotionError.unauthorized`.
  - [ ] A 429 response triggers a 2-second wait and one retry; a second 429 on retry throws `NotionError.rateLimited`.
  - [ ] A 500 response throws `NotionError.serverError(500)`.
  - [ ] A malformed JSON response throws `NotionError.decodingError(_)`.
  - [ ] A `URLError(.notConnectedToInternet)` throws `NotionError.networkError(_)`.
  - [ ] Every request carries the `Authorization: Bearer {token}` header (verify via mock URLSession request capture).
  - [ ] Every request carries the `Notion-Version: 2022-06-28` header.
  - [ ] `createTransaction` appends `[pendingId:{uuid}]` to the Description field in the request body.
  - [ ] `loadToken()` returning `nil` causes `LiveNotionService` to throw `NotionError.unauthorized` before any network call is made.
  - [ ] Two concurrent calls to `fetchDatabases()` are spaced at least 350 ms apart (measure elapsed time via injected clock).
- Integration tests (real Notion sandbox):
  - [ ] `fetchDatabases()` returns at least one database from the sandbox workspace.
  - [ ] `createTransaction` posts a page to the sandbox database and the page appears when queried via `queryTransactions`.
  - [ ] `addCategoryOption("TestCategory")` adds the option and it appears in the next `fetchDatabaseProperties` call.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- All 6 `NotionService` protocol methods work correctly against the real Notion API in a sandbox environment.
- Rate limiting is never triggered during normal app use (350 ms queue prevents consecutive API calls from hitting the 3 req/s limit).
- The token is never logged, stored in memory beyond the request lifetime, or written to any location other than Keychain.
- After swapping `MockNotionService` for `LiveNotionService` at the DI root, the full app works end-to-end with a real Notion workspace.
