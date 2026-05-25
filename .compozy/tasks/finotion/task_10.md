---
status: completed
title: Merchant Alias Management and Settings Screen
type: frontend
complexity: medium
dependencies:
  - task_03
  - task_05
---

# Task 10: Merchant Alias Management and Settings Screen

## Overview
Implements the merchant alias management screen (where users assign friendly names to raw terminal strings) and the app-wide Settings screen (field mapping editor, iCloud sync status, and sign-out). The merchant alias feature is what transforms "RENATA PASCOLLI SOUSA" into "Padaria da Renata" in Notion entries.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `MerchantAliasListView` showing two sections: "Unnamed" (merchants seen but with no alias set) and "Named" (merchants with an alias). Each row shows the raw name and, for Named, the alias beneath it.
- MUST allow the user to tap any merchant row to open an edit sheet where they can type or clear the alias. Clearing the alias moves the merchant back to the "Unnamed" section.
- MUST implement `MerchantAliasViewModel` as `@Observable` with `fetchAll()`, `setAlias(_:for:)`, and `clearAlias(for:)` backed by the SwiftData `MerchantAlias` model.
- Alias lookup MUST be case-insensitive on `rawName`; alias display is stored as the user typed it (original case preserved).
- MUST implement `SettingsView` as a SwiftUI `Form` with: (1) a "Field Mapping" row that opens a read-only summary of the current `FieldMapping` with an "Edit" button that re-enters the onboarding field mapping step; (2) an "iCloud Sync" row showing `AppState.iCloudSyncStatus`; (3) a "Sign Out" button that calls `AppState.signOut()` (clears Keychain token, `FieldMapping` from KV store, and sets `authStatus = .unauthenticated`); (4) an app version/build number row.
- MUST implement `AppState.signOut()` if not already present: clear Keychain token, clear `FieldMapping` from `iCloudKVStoreService`, set `authStatus = .unauthenticated`.
- The "Edit Field Mapping" action MUST re-present only the field mapping step of onboarding (not the full OAuth flow) with the current mapping pre-populated; saving the new mapping updates `AppState.fieldMapping` and persists it via `iCloudKVStoreService`.
- MUST NOT delete `MerchantAlias` SwiftData records when clearing an alias — set `alias = nil` to preserve the merchant's history.
</requirements>

## Subtasks
- [x] 10.1 Create `Features/Aliases/MerchantAliasListView.swift` with two-section list (Unnamed / Named) and tap-to-edit navigation.
- [x] 10.2 Create `Features/Aliases/MerchantAliasViewModel.swift` with `@Observable` CRUD backed by SwiftData `MerchantAlias` model.
- [x] 10.3 Create `Features/Aliases/EditAliasView.swift` — simple sheet with a `TextField` for alias input and a "Clear" button.
- [x] 10.4 Create `Features/Settings/SettingsView.swift` as a `Form` with field mapping summary, iCloud status, sign-out, and version rows.
- [x] 10.5 Implement `AppState.signOut()` in `Core/AppState.swift`.
- [x] 10.6 Wire the "Edit Field Mapping" action via `EditFieldMappingView`; save updates `AppState.fieldMapping` and persists via `iCloudKVStoreService`.
- [x] 10.7 Write unit tests for `MerchantAliasViewModel` and `AppState.signOut()`.

## Implementation Details
See TechSpec "Component Overview — Services" for `MerchantAliasService` role. Note that `MerchantAliasService.resolve(rawName:)` (task_07) and `MerchantAliasViewModel` (this task) both interact with the same `MerchantAlias` SwiftData model — `MerchantAliasService` handles runtime resolution during expense entry; `MerchantAliasViewModel` handles user-facing management.

The "Unnamed" section shows merchants where `MerchantAlias.alias == nil`, sorted by `seenAt` descending (most recently seen first). The "Named" section shows merchants where `alias != nil`, sorted alphabetically by `alias`.

The field mapping editor re-uses `FieldMappingView` from task_06. When presented from Settings, the view receives the current `FieldMapping` as the initial state rather than starting empty. Saving from Settings must NOT call `AppState.completeOnboarding()` — it must only update `fieldMapping` and persist it.

### Relevant Files
- `Finotion/Features/Aliases/MerchantAliasListView.swift` — alias management UI (to create)
- `Finotion/Features/Aliases/MerchantAliasViewModel.swift` — alias CRUD ViewModel (to create)
- `Finotion/Features/Aliases/EditAliasView.swift` — edit alias sheet (to create)
- `Finotion/Features/Settings/SettingsView.swift` — settings form (to create)
- `Finotion/Core/AppState.swift` — add `signOut()` method (to modify)
- `Finotion/Features/Onboarding/Steps/FieldMappingView.swift` — re-used for edit flow (from task_06)
- `FinotionTests/Features/MerchantAliasViewModelTests.swift` — unit tests (to create)

### Dependent Files
- `task_03` (`MerchantAlias` SwiftData model, in-memory container) — persistence layer for aliases.
- `task_04` (`iCloudKVStoreService`, `KeychainService`) — sign-out clears both.
- `task_05` (`AppState`) — `signOut()` method and `iCloudSyncStatus` read from here.
- `task_06` (`FieldMappingView`) — re-used for the edit field mapping flow in Settings.
- `task_07` (`MerchantAliasService`) — shares the same `MerchantAlias` SwiftData records.

## Deliverables
- `Features/Aliases/` module (list, edit views, ViewModel).
- `Features/Settings/SettingsView.swift`.
- `AppState.signOut()` implementation.
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `MerchantAliasViewModel.fetchAll()` returns all `MerchantAlias` records from in-memory container, split into `unnamed` and `named` sections correctly.
  - [ ] `MerchantAliasViewModel.setAlias("Padaria da Renata", for: "RENATA PASCOLLI SOUSA")` updates the `alias` field and moves the record to the `named` section.
  - [ ] `MerchantAliasViewModel.clearAlias(for: "RENATA PASCOLLI SOUSA")` sets `alias = nil` (does not delete the record) and moves it back to `unnamed`.
  - [ ] `AppState.signOut()` clears the token from `MockKeychainService` (`loadToken()` returns `nil` after call).
  - [ ] `AppState.signOut()` clears `FieldMapping` from `MockiCloudKVStoreService` (`load()` returns `nil` after call).
  - [ ] `AppState.signOut()` sets `authStatus = .unauthenticated`.
  - [ ] Unnamed section sorted by `seenAt` descending; named section sorted alphabetically by `alias`.
- Integration tests:
  - [ ] Sign-out flow: `authStatus` transitions to `.unauthenticated` and `OnboardingView` is shown (SwiftUI test host).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- All `MerchantAlias` records with `alias == nil` appear in the "Unnamed" section; records with an alias appear in "Named."
- Editing an alias and saving immediately reflects in the list without requiring a reload.
- Sign-out clears all authentication state and navigates back to onboarding.
- The field mapping editor in Settings pre-populates with the current mapping and saves changes without triggering the full onboarding flow.
