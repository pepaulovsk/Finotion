---
status: completed
title: Expense Entry Form and URL Scheme Handler
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
  - task_05
---

# Task 7: Expense Entry Form and URL Scheme Handler

## Overview
Implements the primary expense capture flow: a bottom-sheet form for manual entry and a URL scheme handler that pre-fills the form from NFC/Shortcuts automations. This is the core user-facing loop that runs every time a purchase is made — it must be fast, reliable, and require minimal taps after an NFC trigger.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `ExpenseEntryViewModel` as an `@Observable` class that accepts an optional `ExpenseEntryIntent` for pre-fill and exposes the form state, validation, and save action.
- MUST implement the `ExpenseEntryIntent` struct with optional fields matching the URL scheme parameters: `merchant: String?`, `amount: Double?`, `paymentMethod: String?`, `date: Date?`.
- MUST implement `URLSchemeHandler` that parses `finotion://add?merchant={}&amount={}&paymentMethod={}&date={}` into an `ExpenseEntryIntent`; all parameters are optional; the `date` parameter is ISO8601-encoded; the handler MUST NOT crash on malformed input.
- MUST register the URL scheme handler in `App.body` via `.onOpenURL` and route the parsed intent to the active `ExpenseEntryViewModel` (presenting the sheet if not already open).
- MUST implement `MerchantAliasService` with `resolve(rawName:) -> String` (returns alias if found, raw name otherwise) and `register(rawName:) async` (upserts a `MerchantAlias` record in SwiftData, marking it as unnamed if no alias exists).
- MUST call `MerchantAliasService.register(rawName:)` on every save, even if the alias already exists, to update `seenAt`.
- The form MUST require `amount` and at least one non-empty `name` before the save button is enabled. `category`, `paymentMethod`, `date`, and `description` are optional.
- On save: resolve the merchant alias, build a `Transaction`, call `NotionService.createTransaction`; on success deliver a haptic success feedback and dismiss the sheet; on failure store a `PendingEntry` in SwiftData (via `SyncService`) and still dismiss with a non-blocking toast warning.
- MUST NOT block the UI on the Notion API call — use a detached async task or structured concurrency; the sheet dismisses immediately after submit.
- MUST implement category selection as a searchable picker that fetches from `CategoryService.fetchCategories(databaseId:)` and allows the user to type a new category inline; new categories are created via `CategoryService.addCategory`.
</requirements>

## Subtasks
- [x] 7.1 Create `Features/ExpenseEntry/ExpenseEntryView.swift` as a bottom sheet with all form fields, a save button, and a loading/success animation.
- [x] 7.2 Create `Features/ExpenseEntry/ExpenseEntryViewModel.swift` with form state, `ExpenseEntryIntent` pre-fill, validation, and save action.
- [x] 7.3 Create `Core/URLSchemeHandler.swift` that parses `finotion://add` parameters into `ExpenseEntryIntent` with graceful handling of missing/malformed values.
- [x] 7.4 Create `Services/Alias/MerchantAliasService.swift` with `resolve(rawName:)` lookup (case-insensitive match against `MerchantAlias.rawName`) and `register(rawName:)` upsert.
- [x] 7.5 Wire `.onOpenURL` in `FinotionApp.swift` / `MainTabView` to parse the URL and present the expense entry sheet pre-filled with the intent.
- [x] 7.6 Implement the category searchable picker backed by `CategoryService`; include inline new-category creation flow.
- [x] 7.7 Write unit tests for `ExpenseEntryViewModel`, `URLSchemeHandler`, and `MerchantAliasService`.

## Implementation Details
See TechSpec "Integration Points — Apple Shortcuts / NFC" for the URL scheme structure and the NFC flow walkthrough. See TechSpec "Technical Considerations — NFC Flow Detail" for the exact sequence of service calls on save.

The `ExpenseEntryIntent` struct captures what arrives from NFC/Shortcuts. On app launch from background via URL, iOS delivers the URL to `onOpenURL` in scene restoration — the handler must be idempotent (calling it twice with the same URL must not create two sheets).

When `NotionService.createTransaction` fails, the `ExpenseEntryViewModel` must create a `PendingEntry` (JSON-encode the `Transaction` with `id` as idempotency key) and hand it to `SyncService.enqueue(_:)`. The `Transaction.id` UUID serves as the idempotency key; it MUST be written into the Notion Description field so duplicates can be detected on retry.

### Relevant Files
- `Finotion/Features/ExpenseEntry/ExpenseEntryView.swift` — bottom sheet UI (to create)
- `Finotion/Features/ExpenseEntry/ExpenseEntryViewModel.swift` — form state machine (to create)
- `Finotion/Core/URLSchemeHandler.swift` — URL scheme parser (to create)
- `Finotion/Services/Alias/MerchantAliasService.swift` — alias resolution service (to create)
- `Finotion/FinotionApp.swift` — `.onOpenURL` wiring (to modify)
- `FinotionTests/Features/ExpenseEntryViewModelTests.swift` — unit tests (to create)
- `FinotionTests/Core/URLSchemeHandlerTests.swift` — unit tests (to create)

### Dependent Files
- `task_02` (`NotionService`, `Transaction`, `MockNotionService`) — API call on save.
- `task_03` (`PendingEntry`, `MerchantAlias`, SwiftData container) — offline queue and alias storage.
- `task_05` (`AppState`, `CategoryService`, environment injection) — category picker backing and context.
- `task_08` (`SyncService.enqueue`) — receives failed `PendingEntry` from the save path.

### Related ADRs
- [ADR-004: Offline Write Queue](../adrs/adr-004.md) — `PendingEntry` created here when Notion call fails; `Transaction.id` is the idempotency key.
- [ADR-005: NotionService Protocol](../adrs/adr-005.md) — `createTransaction` called via protocol; mock used in all tests.

## Deliverables
- `Features/ExpenseEntry/ExpenseEntryView.swift` and `ExpenseEntryViewModel.swift`.
- `Core/URLSchemeHandler.swift`.
- `Services/Alias/MerchantAliasService.swift`.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `URLSchemeHandler.parse("finotion://add?merchant=Padaria&amount=15.50&paymentMethod=credit")` returns `ExpenseEntryIntent` with correct values.
  - [ ] `URLSchemeHandler.parse("finotion://add")` (no parameters) returns an intent with all fields `nil` without crashing.
  - [ ] `URLSchemeHandler.parse("finotion://add?amount=notanumber")` returns an intent with `amount: nil` (graceful parse failure).
  - [ ] `ExpenseEntryViewModel` with no `name` and no `amount` has `isValid == false`; save button disabled.
  - [ ] `ExpenseEntryViewModel` with `name = "Padaria"` and `amount = 15.50` has `isValid == true`.
  - [ ] Calling `save()` on a valid `ExpenseEntryViewModel` calls `MockNotionService.createTransaction` once with the correct `databaseId`.
  - [ ] When `MockNotionService.createTransaction` throws, `ExpenseEntryViewModel.save()` calls `MockSyncService.enqueue(_:)` with a `PendingEntry` whose `id` matches `Transaction.id`.
  - [ ] `MerchantAliasService.resolve(rawName: "RENATA PASCOLLI SOUSA")` returns `"Padaria da Renata"` when that alias exists in the in-memory store.
  - [ ] `MerchantAliasService.resolve(rawName: "UNKNOWN STORE")` returns `"UNKNOWN STORE"` (raw name passthrough) when no alias exists.
  - [ ] `MerchantAliasService.register(rawName: "NEW STORE")` upserts a `MerchantAlias` record with `alias: nil` (unnamed) in the in-memory container.
  - [ ] `ExpenseEntryViewModel` initialized with an `ExpenseEntryIntent(merchant: "Padaria", amount: 12.0)` pre-fills `name = "Padaria"` and `amount = "12.0"` in form state.
- Integration tests:
  - [ ] The `.onOpenURL` handler presenting the sheet with pre-filled data from a valid `finotion://add` URL (SwiftUI test host).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Tapping an NFC tag opens the expense sheet pre-filled within one second.
- Submitting the form dismisses immediately; a success haptic fires; a new entry appears in Notion (or a `PendingEntry` is queued if offline).
- Typing a new category in the picker creates it in Notion and adds it to the list without requiring a page reload.
- The save button is disabled until `name` and `amount` are both provided.
