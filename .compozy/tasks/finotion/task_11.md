---
status: completed
title: Dashboard
type: frontend
complexity: high
dependencies:
  - task_02
  - task_03
  - task_05
  - task_09
---

# Task 11: Dashboard

## Overview
Implements the main dashboard screen: current-month spending summary, per-category totals with budget goal progress, recent transaction history, recurring payment status, and multi-month trend visualizations using Swift Charts. All data is fetched from Notion on demand; no transactions are stored locally. The dashboard is the primary read surface of the app.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `DashboardViewModel` as `@Observable` with sections: `currentMonthTotal`, `categoryTotals: [(category: String, spent: Double, limit: Double?)]`, `recentTransactions: [Transaction]`, `recurringStatus: [(payment: RecurringPayment, dispatched: Bool)]`, and `monthlyTrend: [(yearMonth: String, total: Double)]`.
- On appearance, MUST trigger two parallel async fetches: (1) `queryTransactions` for the current month (for totals + categories + recent list); (2) `queryTransactions` for the last 6 months (for trend chart). Results MUST be merged without double-counting the current month.
- MUST implement `BudgetGoal` auto-carry via `BudgetGoalService.autoCarry(from:to:context:)` on first access of a new month: if no `BudgetGoal` records exist for the current `"YYYY-MM"`, copy all goals from the previous month.
- Category totals section MUST show each category's spent amount alongside its `BudgetGoal.limitAmount` (if set); display a visual progress indicator (bar, ring, or other chart type) per category. The exact chart type is intentionally unspecified — choose the form that best communicates "spent vs. limit."
- Trend section MUST show total spending per month for the last 6 months using Swift Charts. Chart type is intentionally unspecified.
- MUST implement pull-to-refresh that re-fetches all sections.
- MUST display a skeleton/loading state while the first fetch is in progress; if data arrives within 500 ms, skip the skeleton (no flash of empty content).
- MUST display empty states for each section when no data exists (e.g., no transactions this month, no budget goals set, no recurring payments).
- Budget goals MUST be editable inline from the dashboard category row: tapping a category row opens a sheet to set or update the limit for the current month. Changes are persisted to SwiftData immediately.
- MUST call `CategoryService.invalidate()` on pull-to-refresh so that the next category picker access gets fresh data.
</requirements>

## Subtasks
- [x] 11.1 Create `Features/Dashboard/DashboardView.swift` with sections for monthly total, category breakdown, recent transactions, recurring status, and trend chart; include pull-to-refresh and skeleton state.
- [x] 11.2 Create `Features/Dashboard/DashboardViewModel.swift` with parallel fetch logic, section state, and `BudgetGoal` auto-carry trigger.
- [x] 11.3 Implement the category totals section with visual progress indicators, `BudgetGoal` limit display, and tap-to-edit-goal action.
- [x] 11.4 Implement the spending trend chart using Swift Charts for the last 6 months.
- [x] 11.5 Create `Features/Dashboard/SetBudgetGoalView.swift` — sheet for creating or updating a `BudgetGoal` for a specific category and month.
- [x] 11.6 Write unit tests for `DashboardViewModel` data aggregation, auto-carry trigger, and section state transitions.

## Implementation Details
See TechSpec "Technical Considerations — Dashboard Data Strategy" for the fetch strategy, skeleton timing, and cache rules. See TechSpec "Data Models — SwiftData Models" for `BudgetGoal` fields and auto-carry behavior.

`DashboardViewModel` must not persist transaction data between sessions — the in-memory cache is valid only for the current app session. On next launch, the dashboard starts with an empty state and immediately fires a background refresh.

The 500 ms skeleton threshold is implemented by starting a `Task.sleep(for: .milliseconds(500))` race against the first data fetch completion. If the fetch wins, the skeleton is never shown. If the timer wins, show the skeleton until data arrives.

`recurringStatus` is built by loading `RecurringPayment` records from SwiftData and checking whether `lastDispatchedMonth == currentYearMonth` per record. This requires the SwiftData `ModelContext` — fetch this inside a `@MainActor` context.

### Relevant Files
- `Finotion/Features/Dashboard/DashboardView.swift` — main dashboard UI (to create)
- `Finotion/Features/Dashboard/DashboardViewModel.swift` — data aggregation ViewModel (to create)
- `Finotion/Features/Dashboard/SetBudgetGoalView.swift` — budget goal edit sheet (to create)
- `Finotion/Services/Category/BudgetGoalService.swift` — `autoCarry` helper (add to or create; overlaps with task_03 if not extracted)
- `FinotionTests/Features/DashboardViewModelTests.swift` — unit tests (to create)

### Dependent Files
- `task_02` (`NotionService.queryTransactions`, `Transaction`, `MockNotionService`) — all transaction data fetched via protocol.
- `task_03` (`BudgetGoal`, `RecurringPayment`, SwiftData container, `BudgetGoalService.autoCarry`) — local goal and recurring data.
- `task_05` (`AppState`, `CategoryService`, environment) — `CategoryService.invalidate()` on refresh; `fieldMapping` for `databaseId`.
- `task_09` (`RecurringPayment.lastDispatchedMonth`) — used to compute recurring payment status on dashboard.

### Related ADRs
- [ADR-001: Product Approach](../adrs/adr-001.md) — Dashboard is the primary read surface; transactions are not stored locally.
- [ADR-002: iOS 17 Minimum and SwiftData](../adrs/adr-002.md) — Swift Charts requires iOS 16+; @Observable requires iOS 17+.

## Deliverables
- `Features/Dashboard/` module (DashboardView, DashboardViewModel, SetBudgetGoalView).
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `DashboardViewModel` with a `MockNotionService` seeded with 5 transactions in the current month shows `currentMonthTotal` as the correct sum.
  - [ ] Category totals are aggregated correctly: 3 transactions with category "Food" and 2 with "Transport" produce two entries in `categoryTotals`.
  - [ ] A `BudgetGoal` with `limitAmount = 500.0` for "Food" appears in the corresponding `categoryTotals` entry as `limit: 500.0`.
  - [ ] `BudgetGoal` auto-carry: no goals for current month → `BudgetGoalService.autoCarry` is called and copies goals from the previous month into the in-memory container.
  - [ ] `BudgetGoal` auto-carry is NOT called if goals already exist for the current month.
  - [ ] `recurringStatus` correctly marks a `RecurringPayment` as `dispatched: true` when `lastDispatchedMonth == currentYearMonth`.
  - [ ] `recurringStatus` marks a payment as `dispatched: false` when `lastDispatchedMonth` is `nil` or a previous month.
  - [ ] Pull-to-refresh calls `MockNotionService.queryTransactions` again (fetch count increments by at least 1).
  - [ ] `monthlyTrend` contains 6 entries (one per month) when the mock returns data for 6 different `"YYYY-MM"` values.
  - [ ] Empty state: `MockNotionService` returns empty array → `currentMonthTotal == 0` and `categoryTotals` is empty.
- Integration tests:
  - [ ] Dashboard presents correctly in a SwiftUI test host with `MockNotionService.preview` injected; no crashes during section rendering.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Dashboard loads and displays current-month totals within 2 seconds on a real device with a valid Notion token.
- Pull-to-refresh updates all sections with fresh data from Notion.
- Category rows with a budget goal show a visual progress indicator reflecting spent vs. limit.
- Budget goals auto-carry correctly from the previous month when a new month begins.
- All sections have meaningful empty states when no data exists.
