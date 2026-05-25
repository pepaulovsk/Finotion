# Finotion — Technical Specification

## Executive Summary

Finotion is a greenfield SwiftUI iOS 17+ app built with MVVM and @Observable. All financial data lives in the user's Notion workspace; the app never stores transactions locally. Local SwiftData models (synced via CloudKit) persist only operational data: recurring payment definitions, monthly budget goals, merchant aliases, and a pending-write queue for offline resilience. The Notion OAuth token is stored in iCloud Keychain, making the Apple ID the sole identity — no Finotion account exists.

The primary trade-off of this architecture is **Notion dependency**: the app's core value (dashboards, history, categories) is only available when Notion is reachable. This is mitigated by an aggressive caching layer (session-scoped in-memory cache + read from SwiftData for pending entries) and an offline write queue (PendingEntry) that ensures no transaction data is lost during connectivity gaps.

---

## System Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────┐
│                   Finotion.app                      │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  AppState    │  │  Navigation  │  │ URL Scheme│ │
│  │ @Observable  │  │ NavigationSt.│  │  Handler  │ │
│  └──────┬───────┘  └──────────────┘  └─────┬─────┘ │
│         │                                   │       │
│  ┌──────▼───────────────────────────────────▼─────┐ │
│  │              Feature Modules                    │ │
│  │  Onboarding │ Dashboard │ ExpenseEntry          │ │
│  │  Recurring  │ Aliases   │ Settings              │ │
│  └──────┬──────────────────────────────────────────┘ │
│         │                                            │
│  ┌──────▼──────────────────────────────────────────┐ │
│  │                   Services                       │ │
│  │  NotionService  │  SyncService  │ DispatchSvc   │ │
│  │  KeychainSvc    │  CategorySvc  │ AliasSvc      │ │
│  └──────┬──────────────────┬───────────────────────┘ │
│         │                  │                         │
│  ┌──────▼──────┐   ┌───────▼────────────────────┐   │
│  │  SwiftData  │   │  NSUbiquitousKeyValueStore  │   │
│  │ (CloudKit)  │   │  (FieldMapping)             │   │
│  └─────────────┘   └────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐    │
│  │  Keychain (iCloud, kSecAttrSynchronizable)   │    │
│  └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │    Notion API      │
              │  api.notion.com/v1 │
              └────────────────────┘
```

**AppState** — root @Observable class holding auth status, current `FieldMapping`, and iCloud sync state. Injected via SwiftUI Environment at app root.

**Feature Modules** — one directory per feature under `Features/`. Each contains a View, a ViewModel (@Observable), and any feature-local types. Features import Services but never depend on each other.

**Services** — stateless (or lightly stateful) classes injected into ViewModels:
- `NotionService` — all Notion API calls (protocol + live + mock implementations)
- `SyncService` — manages the PendingEntry queue; observes network path; retries failed writes
- `RecurringDispatchService` — deduplication logic and BackgroundTask handler
- `KeychainService` — iCloud Keychain read/write for the OAuth token
- `CategoryService` — in-memory category cache; fetch, create, invalidate
- `MerchantAliasService` — alias lookup and management backed by SwiftData

**SwiftData Store** — CloudKit-synced container with four models: `RecurringPayment`, `BudgetGoal`, `MerchantAlias`, `PendingEntry`.

**NSUbiquitousKeyValueStore** — iCloud KV store for `FieldMapping` (lightweight, no CloudKit schema required).

**Keychain** — stores the Notion access token with `kSecAttrSynchronizable = true` for iCloud Keychain sync across reinstalls.

---

## Implementation Design

### Core Interfaces

```swift
// NotionService — all Notion API operations
protocol NotionService: Sendable {
    func fetchDatabases() async throws -> [NotionDatabase]
    func fetchDatabaseProperties(_ id: String) async throws -> [NotionProperty]
    func createDatabase(parentPageId: String) async throws -> NotionDatabase
    func queryTransactions(databaseId: String, filter: NotionFilter?) async throws -> [Transaction]
    func createTransaction(_ tx: Transaction, databaseId: String) async throws -> String
    func addCategoryOption(_ name: String, databaseId: String, propertyId: String) async throws
}
```

```swift
// FieldMapping — stored in NSUbiquitousKeyValueStore, synced via iCloud KV
struct FieldMapping: Codable, Equatable {
    var databaseId: String
    var nameField: String
    var amountField: String
    var dateField: String
    var typeField: String?
    var categoryField: String?
    var paymentMethodField: String?
    var refDateField: String?
    // Path A (template): all fields are set to the template's known property names
    // Path B (existing): set by user during onboarding field-mapping screen
}
```

```swift
// AppState — root observable state
@Observable
final class AppState {
    var authStatus: AuthStatus = .unknown  // .unknown | .authenticated | .unauthenticated
    var fieldMapping: FieldMapping?
    var iCloudSyncStatus: SyncStatus = .idle
}
```

```swift
// Transaction — the domain model for a single financial entry
struct Transaction: Codable, Identifiable {
    let id: UUID            // local-only; used as pendingId for deduplication
    var name: String        // merchant alias resolved name, or raw name
    var amount: Double
    var date: Date
    var refDate: Date?
    var category: String?
    var paymentMethod: String?
    var description: String?
    var type: TransactionType  // .expense | .income
}
```

### Data Models

#### SwiftData Models (CloudKit-synced)

```swift
@Model class RecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    var dueDay: Int                  // 1–31
    var categoryName: String
    var paymentMethod: String?
    var isActive: Bool
    var lastDispatchedMonth: String? // "YYYY-MM"; nil = never dispatched
    var createdAt: Date
}

@Model class BudgetGoal {
    @Attribute(.unique) var id: UUID
    var categoryName: String
    var yearMonth: String  // "YYYY-MM"
    var limitAmount: Double
}

@Model class MerchantAlias {
    @Attribute(.unique) var rawName: String
    var alias: String?     // nil = unnamed (known but not yet aliased)
    var seenAt: Date
}

@Model class PendingEntry {
    @Attribute(.unique) var id: UUID
    var transactionData: Data  // JSON-encoded Transaction
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var status: String         // "pending" | "synced" | "failed"
}
```

**BudgetGoal auto-carry**: at first access of a new month, `BudgetGoalService` copies all goals from the previous month into the new month if no goals exist for the current month yet.

#### Configuration (NSUbiquitousKeyValueStore)

| Key | Type | Description |
|-----|------|-------------|
| `fieldMapping` | JSON-encoded `FieldMapping` | Notion field → app concept mapping |
| `onboardingCompleted` | Bool | Guards against re-running onboarding |
| `selectedDatabaseId` | String | Redundant with FieldMapping; used for quick access |

#### Keychain

| Key | Description | Attributes |
|-----|-------------|------------|
| `notion_access_token` | Notion OAuth bearer token | `kSecAttrSynchronizable = true`, `kSecAttrAccessibleAfterFirstUnlock` |

### Notion API Endpoints Consumed

| Method | Endpoint | Used for |
|--------|----------|---------|
| `GET` | `/v1/users/me` | Verify token validity on app launch |
| `GET` | `/v1/search` | List databases available to the integration |
| `POST` | `/v1/databases` | Create template database (Path A onboarding) |
| `GET` | `/v1/databases/{id}` | Fetch property schema (field mapping, category options) |
| `PATCH` | `/v1/databases/{id}` | Add new category to select field options |
| `POST` | `/v1/databases/{id}/query` | Query transactions (dashboard, deduplication check) |
| `POST` | `/v1/pages` | Create a new transaction entry |

**Rate limiting**: Notion enforces 3 req/s per integration. `LiveNotionService` implements a serial async queue with a 350 ms minimum interval between requests. Dashboard fetches are batched into a single query where possible.

**Notion-Version header**: `2022-06-28` on all requests.

**Error mapping** (`NotionError` enum):
- `.unauthorized` — 401; triggers re-authentication flow
- `.rateLimited` — 429; backs off 2 seconds and retries once
- `.serverError(Int)` — 5xx; passed to `SyncService` for queue retry
- `.networkError(URLError)` — offline; triggers `PendingEntry` queue
- `.decodingError(Error)` — unexpected response shape; logs and surfaces to user

---

## Integration Points

### Notion API

- **Auth**: OAuth 2.0. User authorizes via `ASWebAuthenticationSession`. The access token is exchanged at Notion's token endpoint and stored in iCloud Keychain. No refresh token — Notion tokens are long-lived; re-auth is triggered only on 401.
- **Retry strategy**: `SyncService` uses `NWPathMonitor` to detect connectivity. On path `.satisfied`, it flushes `PendingEntry` queue with exponential back-off (0 s → 30 s → 2 min → 10 min → 30 min, max 5 attempts).

### Apple Shortcuts / NFC

- **URL scheme**: `finotion://add?merchant={encoded}&amount={double}&paymentMethod={encoded}&date={ISO8601}`
- Registered in `Info.plist` under `CFBundleURLSchemes`.
- Handled in `App.body` via `.onOpenURL`. Parameters are parsed into an `ExpenseEntryIntent` and passed to `ExpenseEntryViewModel` as pre-fill data.
- All parameters are optional. Missing parameters leave the corresponding form field empty.

### BackgroundTasks

- **Task identifier**: `com.finotion.recurring-dispatch`
- Registered in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
- `RecurringDispatchService.handleBackgroundTask(_:)` runs the dispatch loop:
  1. Load all active `RecurringPayment` records where `dueDay == today`
  2. Skip if `lastDispatchedMonth == currentYearMonth`
  3. Query Notion for existing entry (deduplication secondary check)
  4. Post to Notion; update `lastDispatchedMonth`
  5. Fire local `UNUserNotificationCenter` notification (success or failure)
- Task is rescheduled immediately after completion for the next calendar day.

### iCloud / CloudKit

- SwiftData container uses `ModelConfiguration(cloudKitContainerIdentifier: "iCloud.com.finotion.app")`.
- `NSUbiquitousKeyValueStore` sync is activated by calling `.synchronize()` on app foreground.
- Keychain entries use `kSecAttrSynchronizable = true` — synced automatically by iOS.

---

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|----------------------|-----------------|
| Xcode Project | New | Greenfield — iOS 17 target, SwiftData, CloudKit, BackgroundTasks, iCloud KV | Create project, configure entitlements |
| SwiftData schema | New | 4 models; CloudKit schema auto-generated on first launch | Implement models; test migration path |
| NotionService | New | Protocol + live implementation + mock | Implement; write unit tests with mock |
| SyncService | New | PendingEntry queue + NWPathMonitor retry | Implement; test offline/online transitions |
| RecurringDispatchService | New | BGAppRefreshTask + deduplication + local notifications | Implement; test with Xcode BGTask debugger |
| KeychainService | New | iCloud Keychain read/write wrapper | Implement; test iCloud sync scenario |
| Onboarding flow | New | OAuth + DB path fork + field mapping | Implement; covers both Path A and Path B |
| URL scheme handler | New | Deep link parsing for Shortcuts integration | Implement; test with Shortcuts automation |
| Feature modules | New | 6 modules: Dashboard, ExpenseEntry, Recurring, Aliases, Settings, Onboarding | Implement per build order below |

---

## Testing Approach

### Unit Tests

- **`NotionServiceTests`**: use `MockNotionService`; test serialization of all request types; test error mapping for 401/429/5xx responses; test `NotionFilter` query construction.
- **`FieldMappingTests`**: test `Codable` round-trip; test `NSUbiquitousKeyValueStore` persistence; test optional field handling (skipped fields return `nil`, features disabled gracefully).
- **`RecurringDispatchTests`**: test deduplication (same month, already dispatched); test value versioning (amount change applies to current month, not previous); test due-day edge cases (31st in 30-day months → skipped, dispatched on last day).
- **`MerchantAliasTests`**: test alias lookup (exact match, case-insensitive); test new merchant registration (added to unnamed list, no alias applied); test alias update.
- **`PendingEntryTests`**: test retry backoff sequence; test deduplication on retry (idempotency key check); test max-retry failure state.
- **`BudgetGoalTests`**: test auto-carry (no goals for new month → copies from previous); test month-scoped adjustment (change in May does not affect June).

### Integration Tests

- **Notion sandbox**: create a test Notion database via API; run `LiveNotionService.createTransaction`; verify entry appears with correct field values; test field mapping with non-English property names.
- **BackgroundTask**: use Xcode's BGTask debugger (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.finotion.recurring-dispatch"]`); verify dispatch creates a Notion entry and updates `lastDispatchedMonth`.
- **iCloud restore**: delete app; reinstall; verify `FieldMapping` restored from NSUbiquitousKeyValueStore; verify SwiftData models restored from CloudKit; verify OAuth token restored from iCloud Keychain.

---

## Development Sequencing

### Build Order

1. **Xcode project scaffold** — Create project (iOS 17, SwiftUI app), configure entitlements (CloudKit, iCloud KV Store, BackgroundTasks, Keychain Sharing), register URL scheme `finotion://`. No dependencies.

2. **NotionService protocol + MockNotionService** — Define the full protocol and an in-memory mock. All other feature work depends on this mock to develop without a real Notion account. Depends on: step 1.

3. **SwiftData schema + CloudKit container** — Implement all four `@Model` classes, configure `ModelContainer` with CloudKit. Depends on: step 1.

4. **KeychainService + NSUbiquitousKeyValueStore wrapper** — Implement iCloud Keychain read/write and iCloud KV Store read/write for FieldMapping. Depends on: step 1.

5. **AppState + dependency injection root** — Implement root `@Observable AppState`, wire services into SwiftUI Environment, set up `NavigationStack`. Depends on: steps 2, 3, 4.

6. **Onboarding flow** — OAuth via `ASWebAuthenticationSession`, DB list/select, Path A (template creation) / Path B (field mapping screen), Shortcut install, notification permission. Depends on: steps 2, 4, 5.

7. **Expense entry form + URL scheme handler** — Bottom sheet form UI, `ExpenseEntryViewModel`, URL scheme deep-link parser, `MerchantAliasService` lookup, `NotionService.createTransaction` call. Depends on: steps 2, 3, 4, 5.

8. **SyncService + PendingEntry queue** — `NWPathMonitor` observer, flush-on-connect logic, retry backoff, idempotency key deduplication. Depends on: steps 2, 3, 7.

9. **Recurring payments module** — CRUD UI, `RecurringDispatchService`, `BGAppRefreshTask` handler, local notifications. Depends on: steps 2, 3, 5.

10. **Dashboard** — `DashboardViewModel`, `NotionService.queryTransactions`, in-memory category cache, `BudgetGoal` auto-carry, Swift Charts visualizations. Depends on: steps 2, 3, 5, 9.

11. **Merchant alias management screen + Settings** — `MerchantAliasService` CRUD, unnamed merchant list, Settings screen with all configuration options and field mapping editor. Depends on: steps 3, 5.

12. **LiveNotionService (URLSession)** — Replace mock with production implementation: build all Notion JSON request/response codables, wire rate limiting, map errors to `NotionError`. Depends on: step 2 (implements the protocol).

13. **End-to-end testing + polish** — Real Notion integration tests, BackgroundTask simulator tests, iCloud restore test, haptic feedback, loading states, empty states. Depends on: all above.

### Technical Dependencies

- Apple Developer account with CloudKit and BackgroundTasks capabilities enabled.
- Notion integration registered at `notion.so/my-integrations` with OAuth credentials (client ID + secret). Required before step 6.
- A test Notion workspace for integration tests (step 13).

---

## Monitoring and Observability

Since Finotion is a personal tool with no external telemetry:

- **OSLog**: structured logging in all services. Log category per service (e.g., `Logger(subsystem: "com.finotion", category: "NotionService")`). Debug builds log full request/response bodies (with token redacted); release builds log only outcomes.
- **Key log events**: OAuth success/failure, transaction posted (with pendingId), PendingEntry retry attempt (with retry count), recurring dispatch outcome (dispatched / skipped / failed), iCloud sync status change, BackgroundTask start/end.
- **No external SDK**: no Sentry, Firebase, or analytics. All observability is local to the device.

---

## Technical Considerations

### Feature Access Abstraction

To keep the codebase future-proof for a potential paywall (per PRD), a `FeatureAccess` protocol gates all features from day one:

```swift
protocol FeatureAccess {
    var recurringPayments: Bool { get }
    var merchantAliases: Bool { get }
    var notificationCapture: Bool { get }  // Phase 2
    var incomeTracking: Bool { get }       // Phase 2
}

struct FullAccess: FeatureAccess {
    var recurringPayments: Bool { true }
    var merchantAliases: Bool { true }
    var notificationCapture: Bool { false }
    var incomeTracking: Bool { false }
}
```

`FullAccess` is the only implementation in the MVP. If a paywall is added, a `PremiumGatedAccess` implementation is swapped in via dependency injection — zero changes to feature code.

### Category Sync

Categories are Notion Select field options. The app does not cache them in SwiftData — only in memory for the session:
- `CategoryService` fetches on first access (app open or screen appear)
- Invalidated and re-fetched on app foreground and pull-to-refresh
- New categories posted via `PATCH /v1/databases/{id}` and appended to the in-memory cache immediately (optimistic update)
- If the API call fails, the new category is removed from the cache and the user sees an error

### NFC Flow Detail

1. User taps NFC sticker → iOS reads NDEF record containing the URL `finotion://add?merchant=...&paymentMethod=creditCard`
2. iOS opens Finotion (or brings it to foreground) via `onOpenURL`
3. `URLSchemeHandler` parses parameters into `ExpenseEntryIntent`
4. `ExpenseEntryViewModel` is initialized with the intent; the bottom sheet opens pre-filled
5. User provides amount and category (the two required fields not auto-populated by NFC)
6. On save: `MerchantAliasService.resolve(rawName:)` → `NotionService.createTransaction` → `SyncService` handles success/failure

### Recurring Payment Value Versioning

`RecurringPayment.amount` always holds the current configured value. When the user edits the amount, the `lastDispatchedMonth` is NOT reset — only future dispatches use the new amount. Entries already in Notion (from prior months) are immutable. The dispatch service always reads `amount` at dispatch time, which is the current value on the model — this naturally implements "new value from now forward."

### Dashboard Data Strategy

Dashboard data is not stored in SwiftData (transactions live in Notion). The fetch strategy:
- On app open: display last session's in-memory cache instantly; trigger background refresh
- Background refresh calls `queryTransactions` for current month (for totals, category breakdown) and last 6 months (for trend chart) in two parallel async calls
- On pull-to-refresh: re-fetch all sections
- The in-memory cache is not persisted between app sessions — next launch always shows a brief skeleton state while the first fetch completes (unless data appears within 500 ms, in which case the skeleton is skipped)

### iCloud Sync Sequencing on Reinstall

On first launch after reinstall:
1. App checks iCloud Keychain for `notion_access_token`
2. If found: skip OAuth, restore `AppState.authStatus = .authenticated`
3. NSUbiquitousKeyValueStore loads `FieldMapping` (may take a few seconds for iCloud propagation)
4. SwiftData container merges CloudKit records in background
5. App shows a "Restoring your data…" loading state until `FieldMapping` is available
6. If iCloud is unavailable: proceed with empty state and show a one-time banner

---

## Architecture Decision Records

- [ADR-001: Product Approach — Notion Finance Companion](adrs/adr-001.md) — Lightweight iOS companion; Notion is the single source of truth; no custom backend.
- [ADR-002: iOS 17 Minimum and SwiftData](adrs/adr-002.md) — SwiftData + @Observable chosen over CoreData for cleaner APIs; iOS 17 covers 90%+ of active devices.
- [ADR-003: MVVM with @Observable](adrs/adr-003.md) — Simple MVVM over TCA or MVVM+Coordinator; no third-party architecture dependencies.
- [ADR-004: Offline Write Queue with Auto-Retry](adrs/adr-004.md) — PendingEntry in SwiftData; NWPathMonitor triggers flush; idempotency key in Notion Description field prevents duplicates.
- [ADR-005: NotionService Protocol](adrs/adr-005.md) — Protocol-backed abstraction with live URLSession and mock implementations; no third-party Notion SDK.
