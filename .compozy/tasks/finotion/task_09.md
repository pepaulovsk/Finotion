---
status: pending
title: Recurring Payments Module
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
  - task_05
---

# Task 9: Recurring Payments Module

## Overview
Implements the full recurring payments feature: a CRUD management screen, a `RecurringDispatchService` that auto-posts due payments via `BGAppRefreshTask`, deduplication logic to prevent double-posting in the same month, and local notifications for dispatch outcomes. This feature covers all recurring obligations — subscriptions, rent, insurance, loan installments, utility bills.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement a `RecurringPaymentsView` with a list of active/inactive recurring payments, add/edit/delete actions, and a per-payment status indicator showing whether the current month's dispatch has been posted.
- MUST implement `RecurringPaymentsViewModel` as `@Observable` with CRUD operations that read and write `RecurringPayment` SwiftData records.
- MUST implement `RecurringDispatchService` with a `handleBackgroundTask(_ task: BGAppRefreshTask)` method that: loads all active `RecurringPayment` records where `dueDay == todayDay`; skips any where `lastDispatchedMonth == currentYearMonth`; performs a secondary Notion deduplication query; posts to Notion via `NotionService.createTransaction`; updates `lastDispatchedMonth`; fires a local `UNUserNotificationCenter` notification (success or failure per payment).
- MUST register the background task identifier `com.finotion.recurring-dispatch` via `BGTaskScheduler.shared.register` in `AppDelegate` or the app entry point, and reschedule immediately after each execution.
- MUST implement value versioning: when a user edits `RecurringPayment.amount`, the existing `lastDispatchedMonth` is NOT reset — the new amount applies only to future dispatches. Past Notion entries are immutable.
- MUST handle `dueDay` edge cases: if `dueDay = 31` and the current month has only 30 days, dispatch on the last day of the month (day 30); same logic for February.
- MUST NOT dispatch a payment if the notification permission has been denied AND the user has not manually opened the recurring screen — silent background dispatch is acceptable even without notification permission, but the local notification is skipped rather than causing an error.
- The dispatch background task MUST call `task.setTaskCompleted(success:)` regardless of Notion success/failure to prevent iOS from penalizing the app's background execution budget.
</requirements>

## Subtasks
- [ ] 9.1 Create `Features/RecurringPayments/RecurringPaymentsView.swift` with a list, add button, and swipe-to-delete; show the current-month dispatch status badge per row.
- [ ] 9.2 Create `Features/RecurringPayments/RecurringPaymentsViewModel.swift` with `@Observable` CRUD backed by SwiftData and a `currentMonthStatus(for:)` helper.
- [ ] 9.3 Create `Features/RecurringPayments/AddEditRecurringPaymentView.swift` — form for creating or editing a recurring payment (name, amount, dueDay 1–31, category, paymentMethod, isActive).
- [ ] 9.4 Create `Services/Dispatch/RecurringDispatchService.swift` implementing the background dispatch loop, deduplication, last-month guard, due-day edge cases, and local notifications.
- [ ] 9.5 Register `com.finotion.recurring-dispatch` in the app entry point and wire `BGTaskScheduler.shared.register` to `RecurringDispatchService.handleBackgroundTask`.
- [ ] 9.6 Write unit tests for `RecurringDispatchService` dispatch logic, deduplication, value versioning, and due-day edge cases.

## Implementation Details
See TechSpec "Integration Points — BackgroundTasks" for the exact dispatch loop steps and rescheduling pattern. See TechSpec "Technical Considerations — Recurring Payment Value Versioning" for the amount-change behavior.

The `RecurringDispatchService` builds a `Transaction` from each `RecurringPayment` at dispatch time using the current `amount` field value. The `Transaction.id` is a fresh `UUID()` generated per dispatch — each monthly posting is a distinct idempotency unit. The Notion Description field includes `[recurringId:{payment.id}][month:{YYYY-MM}]` so deduplication can match on a secondary query.

To simulate the background task during development, use: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.finotion.recurring-dispatch"]` in the Xcode debugger.

### Relevant Files
- `Finotion/Features/RecurringPayments/RecurringPaymentsView.swift` — list UI (to create)
- `Finotion/Features/RecurringPayments/RecurringPaymentsViewModel.swift` — CRUD ViewModel (to create)
- `Finotion/Features/RecurringPayments/AddEditRecurringPaymentView.swift` — form (to create)
- `Finotion/Services/Dispatch/RecurringDispatchService.swift` — background dispatch (to create)
- `Finotion/FinotionApp.swift` — BGTaskScheduler registration (to modify)
- `FinotionTests/Services/RecurringDispatchServiceTests.swift` — unit tests (to create)

### Dependent Files
- `task_02` (`NotionService`, `MockNotionService`, `Transaction`) — `createTransaction` called per dispatch.
- `task_03` (`RecurringPayment` SwiftData model, in-memory container) — persistence layer for recurring payment definitions.
- `task_05` (`AppState`, environment) — `RecurringPaymentsViewModel` reads services from environment.
- `task_11` (Dashboard) — reads `RecurringPayment` records to show status summary on dashboard.

### Related ADRs
- [ADR-004: Offline Write Queue](../adrs/adr-004.md) — Dispatch failures from `RecurringDispatchService` may also produce `PendingEntry` records if connectivity is down.
- [ADR-001: Product Approach](../adrs/adr-001.md) — Recurring payments scope includes all periodic obligations, not just subscriptions.

## Deliverables
- `Features/RecurringPayments/` module with View, ViewModel, and Add/Edit form.
- `Services/Dispatch/RecurringDispatchService.swift`.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `RecurringDispatchService` skips a payment where `lastDispatchedMonth == currentYearMonth` (already dispatched this month).
  - [ ] `RecurringDispatchService` dispatches a payment where `lastDispatchedMonth != currentYearMonth` and calls `MockNotionService.createTransaction` once.
  - [ ] After successful dispatch, `RecurringPayment.lastDispatchedMonth` is updated to the current `"YYYY-MM"` string.
  - [ ] Editing `RecurringPayment.amount` does NOT reset `lastDispatchedMonth`; the next dispatch uses the new amount.
  - [ ] `dueDay = 31` in a 30-day month dispatches on day 30 (last day of month).
  - [ ] `dueDay = 31` in February dispatches on day 28 (or 29 in a leap year).
  - [ ] Deduplication: `MockNotionService.queryTransactions` returns a result matching `[recurringId:{id}][month:{YYYY-MM}]` → `createTransaction` is NOT called; `lastDispatchedMonth` is still updated.
  - [ ] `RecurringDispatchService` fires a `UNUserNotificationCenter` success notification after a successful dispatch (mock notification center).
  - [ ] `RecurringDispatchService` fires a failure notification and does NOT throw when `NotionService.createTransaction` fails.
  - [ ] Inactive payments (`isActive = false`) are skipped by the dispatch loop.
  - [ ] `RecurringPaymentsViewModel.delete(_:)` removes the `RecurringPayment` from the in-memory SwiftData container.
- Integration tests:
  - [ ] Full dispatch flow using in-memory container and `MockNotionService`: 3 active payments, 1 already dispatched → 2 new Notion entries created.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- A recurring payment due today is posted to Notion automatically by the background task without requiring the app to be open.
- A payment that was already dispatched this month is never double-posted, even if the background task runs multiple times.
- Editing the amount of an active recurring payment updates only future dispatches — past Notion entries remain unchanged.
- The recurring payments list correctly shows which payments have been dispatched in the current month.
