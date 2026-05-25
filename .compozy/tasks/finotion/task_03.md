---
status: completed
title: SwiftData Schema and CloudKit Container
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 3: SwiftData Schema and CloudKit Container

## Overview
Defines the four SwiftData `@Model` classes that store all on-device persistent data and configures the shared `ModelContainer` with CloudKit sync. This task establishes the persistence layer that recurring payments, budget goals, merchant aliases, and the offline write queue all depend on.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement four `@Model` classes: `RecurringPayment`, `BudgetGoal`, `MerchantAlias`, `PendingEntry` with the fields specified in the TechSpec "Data Models — SwiftData Models" section.
- `RecurringPayment.id` and `PendingEntry.id` MUST be marked `@Attribute(.unique)`.
- `MerchantAlias.rawName` MUST be marked `@Attribute(.unique)` (the raw merchant name is the primary key).
- MUST create a shared `ModelContainer` configured with the CloudKit container identifier `iCloud.com.finotion.app`.
- The `ModelContainer` MUST be injected into the SwiftUI environment at the app root (coordination with task_05, but the container itself is defined here).
- `BudgetGoal` MUST store a `yearMonth: String` field in `"YYYY-MM"` format — the combination of `categoryName + yearMonth` is logically unique.
- `PendingEntry.status` MUST be a `String` (not an enum) to avoid SwiftData enum storage complexity; valid values are `"pending"`, `"synced"`, `"failed"`.
- MUST NOT connect to CloudKit in tests — use an in-memory `ModelContainer` in all unit tests.
</requirements>

## Subtasks
- [ ] 3.1 Create `Models/RecurringPayment.swift`, `Models/BudgetGoal.swift`, `Models/MerchantAlias.swift`, `Models/PendingEntry.swift` with all fields from the TechSpec.
- [ ] 3.2 Create `Core/DataContainer.swift` with a `makeContainer(inMemory:)` factory that returns a `ModelContainer` configured for CloudKit (production) or in-memory (tests).
- [ ] 3.3 Add a `BudgetGoalService.autoCarry(from:to:context:)` static helper that copies all goals from one `yearMonth` to another if the destination has no existing goals — this logic is self-contained and belongs next to the model.
- [ ] 3.4 Write unit tests for all models using in-memory containers: create, read, update, delete, and uniqueness constraint enforcement.

## Implementation Details
See TechSpec "Data Models — SwiftData Models" for all field names, types, and constraints. See TechSpec "Technical Considerations — Dashboard Data Strategy" for the `BudgetGoal` auto-carry behavior.

The `makeContainer(inMemory: true)` path is used in all unit and UI tests. The `inMemory: false` path is used in production and enabled CloudKit sync automatically when the CloudKit container is properly configured in entitlements (task_01).

### Relevant Files
- `Finotion/Models/RecurringPayment.swift` — SwiftData model (to create)
- `Finotion/Models/BudgetGoal.swift` — SwiftData model (to create)
- `Finotion/Models/MerchantAlias.swift` — SwiftData model (to create)
- `Finotion/Models/PendingEntry.swift` — SwiftData model (to create)
- `Finotion/Core/DataContainer.swift` — ModelContainer factory (to create)
- `FinotionTests/Models/SwiftDataTests.swift` — unit tests (to create)

### Dependent Files
- `task_05` (AppState root) inserts the `ModelContainer` into the SwiftUI environment.
- `task_07` (ExpenseEntry) creates `PendingEntry` records on failed Notion writes.
- `task_08` (SyncService) reads and updates `PendingEntry` records.
- `task_09` (RecurringPayments) reads and writes `RecurringPayment` records.
- `task_10` (Settings/Aliases) reads and writes `MerchantAlias` records.
- `task_11` (Dashboard) reads `BudgetGoal` and `RecurringPayment` records.

### Related ADRs
- [ADR-002: iOS 17 Minimum and SwiftData](../adrs/adr-002.md) — Explains the SwiftData + CloudKit choice over CoreData.
- [ADR-004: Offline Write Queue](../adrs/adr-004.md) — `PendingEntry` model is the persistence layer for the retry queue.

## Deliverables
- Four SwiftData `@Model` files in `Models/`.
- `Core/DataContainer.swift` with `makeContainer(inMemory:)` factory.
- `BudgetGoalService.autoCarry` helper with unit tests.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `RecurringPayment` can be inserted, fetched, and deleted in an in-memory container.
  - [ ] Inserting two `RecurringPayment` records with the same `id` throws a uniqueness violation.
  - [ ] `MerchantAlias` uniqueness on `rawName`: inserting a duplicate `rawName` throws a violation.
  - [ ] `PendingEntry` status transitions: insert with `"pending"`, update to `"synced"`, verify fetch returns updated value.
  - [ ] `BudgetGoalService.autoCarry(from:to:)` copies three goals from "2026-04" to "2026-05" when "2026-05" is empty.
  - [ ] `BudgetGoalService.autoCarry(from:to:)` does NOT overwrite existing goals in the target month.
  - [ ] `BudgetGoal` with `yearMonth = "2026-05"` and `categoryName = "Food"` is distinct from one with `yearMonth = "2026-06"`.
- Integration tests:
  - [ ] `makeContainer(inMemory: false)` initializes without crashing (CloudKit sync is asynchronous — just verify no crash on init).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- All four model files compile with no warnings.
- In-memory container used in all tests — no tests make real CloudKit calls.
- `autoCarry` correctly scopes goal copies to the current month only.
