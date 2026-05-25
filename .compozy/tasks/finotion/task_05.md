---
status: pending
title: AppState, Dependency Injection Root and CategoryService
type: frontend
complexity: medium
dependencies:
  - task_02
  - task_03
  - task_04
---

# Task 5: AppState, Dependency Injection Root and CategoryService

## Overview
Wires together the app's root-level state, service dependencies, and navigation structure so all feature modules can be built on a stable foundation. Also implements `CategoryService` — a shared session-scoped cache of Notion category options used by expense entry, recurring payments, and any future feature that needs category selection. Without this task, no feature module can be integrated.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `AppState` as an `@Observable` class with properties: `authStatus: AuthStatus`, `fieldMapping: FieldMapping?`, `iCloudSyncStatus: SyncStatus`.
- `AuthStatus` MUST be an enum with cases `.unknown`, `.authenticated`, `.unauthenticated`.
- MUST implement `FeatureAccess` protocol and `FullAccess` struct as specified in the TechSpec "Technical Considerations — Feature Access Abstraction" section.
- MUST inject `AppState`, `ModelContainer`, `NotionService`, `KeychainService`, and `iCloudKVStoreService` via SwiftUI `.environment()` or `.environmentObject()` at the app root in `FinotionApp.swift`.
- MUST register an `NSUbiquitousKeyValueStore.didChangeExternallyNotification` observer to re-load `FieldMapping` when iCloud propagates changes (handles the reinstall restore scenario).
- MUST call `NSUbiquitousKeyValueStore.default.synchronize()` on `scenePhase == .active`.
- MUST implement `CategoryService` with: `fetchCategories(databaseId:) async throws -> [String]`, `addCategory(_:databaseId:) async throws`, `invalidate()`, and a session-scoped in-memory cache (re-fetched on each app foreground, invalidated on `invalidate()` call).
- On app launch, `AppState` MUST read the Keychain for a token and `iCloudKVStoreService` for a `FieldMapping`; if both are present, set `authStatus = .authenticated` and skip onboarding.
</requirements>

## Subtasks
- [ ] 5.1 Create `Core/AppState.swift` with `AuthStatus`, `SyncStatus` enums and the `@Observable AppState` class.
- [ ] 5.2 Create `Core/FeatureAccess.swift` with the `FeatureAccess` protocol and `FullAccess` struct.
- [ ] 5.3 Update `FinotionApp.swift` to instantiate all services, insert the `ModelContainer` into the environment, and set up the root `NavigationStack` that switches between onboarding and main tab views based on `AppState.authStatus`.
- [ ] 5.4 Register the `NSUbiquitousKeyValueStore` change notification and `scenePhase` observer for `synchronize()` calls.
- [ ] 5.5 Create `Services/Category/CategoryService.swift` with in-memory cache, fetch, add, and invalidate methods.
- [ ] 5.6 Write unit tests for `AppState` launch state resolution and `CategoryService` cache behavior.

## Implementation Details
See TechSpec "System Architecture — AppState" and "Technical Considerations — Category Sync" sections.

The root view structure is: if `authStatus == .unauthenticated || .unknown` → show `OnboardingView`. If `.authenticated` → show `MainTabView`. `AppState` resolves this synchronously on launch by reading Keychain and KV store; the `.unknown` state is only transient during the very first frame.

### Relevant Files
- `Finotion/Core/AppState.swift` — root observable state (to create)
- `Finotion/Core/FeatureAccess.swift` — feature gating protocol (to create)
- `Finotion/FinotionApp.swift` — DI root and app lifecycle (to modify)
- `Finotion/Services/Category/CategoryService.swift` — Notion category cache (to create)
- `FinotionTests/Core/AppStateTests.swift` — unit tests (to create)

### Dependent Files
- All feature ViewModels (tasks 06–11) depend on `AppState` being in the environment.
- `task_06` (Onboarding) writes to `AppState.fieldMapping` and transitions `authStatus` to `.authenticated`.
- `task_07` (ExpenseEntry) calls `CategoryService.fetchCategories()`.
- `task_09` (RecurringPayments) calls `CategoryService.fetchCategories()` for category selection.

### Related ADRs
- [ADR-003: MVVM with @Observable](../adrs/adr-003.md) — Establishes `AppState` as the root @Observable injected via Environment.
- [ADR-002: iOS 17 Minimum and SwiftData](../adrs/adr-002.md) — Confirms `NSUbiquitousKeyValueStore` for `FieldMapping` sync.

## Deliverables
- `Core/AppState.swift`, `Core/FeatureAccess.swift`.
- Updated `FinotionApp.swift` with DI root, environment injection, and scene phase observer.
- `Services/Category/CategoryService.swift`.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `AppState` with a valid Keychain token and `FieldMapping` in KV store → `authStatus` is `.authenticated` after `resolveAuthStatus()`.
  - [ ] `AppState` with no Keychain token → `authStatus` is `.unauthenticated`.
  - [ ] `AppState` with a token but no `FieldMapping` → `authStatus` is `.unauthenticated` (onboarding is not complete).
  - [ ] `FullAccess.recurringPayments` returns `true`; `FullAccess.notificationCapture` returns `false` (Phase 2 gated).
  - [ ] `CategoryService` first call fetches from `NotionService` (mock); second call returns cached value without a second fetch.
  - [ ] `CategoryService.invalidate()` then next call triggers a fresh fetch from `NotionService`.
  - [ ] `CategoryService.addCategory("Pets", databaseId:)` calls `MockNotionService.addCategoryOption` and appends "Pets" to the in-memory cache immediately.
- Integration tests:
  - [ ] App root view displays `OnboardingView` when `authStatus == .unauthenticated`.
  - [ ] App root view displays `MainTabView` when `authStatus == .authenticated`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- App launches, reads Keychain and KV store, and routes to the correct root view within one frame.
- All feature tasks (06–11) can be built using `MockNotionService` injected at the DI root.
