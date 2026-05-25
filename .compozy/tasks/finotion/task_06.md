---
status: pending
title: Onboarding Flow
type: frontend
complexity: high
dependencies:
  - task_02
  - task_04
  - task_05
---

# Task 6: Onboarding Flow

## Overview
Implements the guided onboarding experience that connects Finotion to the user's Notion workspace. Covers the OAuth authentication step, the two-path database selection (Path A: template creation; Path B: existing database with field mapping), and the optional Shortcut install and notification permission steps. After onboarding completes, `AppState.authStatus` transitions to `.authenticated` and the user never sees onboarding again.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement OAuth 2.0 via `ASWebAuthenticationSession` with Notion's authorization URL; exchange the code for a token at Notion's token endpoint; store the token in Keychain via `KeychainService`.
- MUST present the two-path database choice: Path A (create template) calls `NotionService.createDatabase(parentPageId:)` and auto-populates the `FieldMapping` with the known template schema. Path B (existing database) shows a database list and a field-mapping screen.
- The field mapping screen (Path B) MUST list all properties of the selected database and let the user assign each app concept to a property. Optional fields can be skipped. The mapping MUST be saved via `iCloudKVStoreService`.
- MUST implement the Shortcut install step as a deep link to `shortcuts://import-shortcut?url=<URL>&name=Register+Expense`; the step MUST be skippable.
- MUST implement the notification permission step using `UNUserNotificationCenter.requestAuthorization`; MUST be skippable.
- After all required steps complete, MUST call `AppState.completeOnboarding()` (sets `authStatus = .authenticated` and stores the flag in `iCloudKVStoreService`).
- MUST handle OAuth errors (user cancels session, network error, invalid token response) with informative error messages and a "Try again" option.
- MUST NOT block on iCloud sync completion — proceed immediately after writing `FieldMapping` to KV store.
</requirements>

## Subtasks
- [ ] 6.1 Create `Features/Onboarding/OnboardingView.swift` as a paged flow (using `TabView` with `.page` style or a custom step controller).
- [ ] 6.2 Implement `Features/Onboarding/OnboardingViewModel.swift` handling OAuth, database fetching, template creation, and step progression logic.
- [ ] 6.3 Implement the OAuth step: `ASWebAuthenticationSession` → code exchange → `KeychainService.save(token:)`.
- [ ] 6.4 Implement the database path selection step with Path A (template) and Path B (existing database list + field mapping screen).
- [ ] 6.5 Implement the field mapping screen (`FieldMappingView`) for Path B: show available Notion properties, let user assign each concept, validate that `nameField`, `amountField`, and `dateField` are assigned before allowing proceed.
- [ ] 6.6 Implement Shortcut install step (deep link) and notification permission step; both skippable.
- [ ] 6.7 Write unit tests for `OnboardingViewModel` state transitions and error handling.

## Implementation Details
See PRD "Core Features — Onboarding" and TechSpec "Integration Points — Notion API" for the OAuth flow and database path details. See TechSpec "Data Models — Configuration" for the keys used in `iCloudKVStoreService`.

The Notion OAuth authorization URL is `https://api.notion.com/v1/oauth/authorize?client_id=...&response_type=code&owner=user&redirect_uri=finotion://oauth`. The token exchange endpoint is `https://api.notion.com/v1/oauth/token` with `Basic` auth using `client_id:client_secret`.

Notion OAuth client credentials (client ID + secret) are stored in the app bundle as constants (not in source control in production — use Xcode build configurations or a secrets file excluded from git).

### Relevant Files
- `Finotion/Features/Onboarding/OnboardingView.swift` — step container view (to create)
- `Finotion/Features/Onboarding/OnboardingViewModel.swift` — onboarding state machine (to create)
- `Finotion/Features/Onboarding/Steps/ConnectNotionStepView.swift` — OAuth step UI (to create)
- `Finotion/Features/Onboarding/Steps/DatabasePathStepView.swift` — path A/B selection (to create)
- `Finotion/Features/Onboarding/Steps/FieldMappingView.swift` — Path B field mapper (to create)
- `Finotion/Features/Onboarding/Steps/ShortcutInstallStepView.swift` — Shortcut install (to create)
- `Finotion/Features/Onboarding/Steps/NotificationPermissionStepView.swift` — permission step (to create)
- `FinotionTests/Features/OnboardingViewModelTests.swift` — unit tests (to create)

### Dependent Files
- `task_05` (`AppState`) — `completeOnboarding()` method called at end of flow.
- `task_04` (`KeychainService`, `iCloudKVStoreService`) — token and FieldMapping storage.
- `task_02` (`NotionService.fetchDatabases`, `createDatabase`, `fetchDatabaseProperties`) — API calls during onboarding.

### Related ADRs
- [ADR-001: Product Approach — Notion Finance Companion](../adrs/adr-001.md) — Two database paths (template vs. existing) stem from the companion product identity.

## Deliverables
- Full onboarding flow: 5 steps (OAuth, DB path, field mapping, Shortcut install, notification permission).
- `OnboardingViewModel` with testable state machine.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for OAuth and database fetching **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `OnboardingViewModel` starts at step `.connectNotion`; calling `completeOAuth(token:)` advances to `.chooseDatabase`.
  - [ ] Path A selection calls `MockNotionService.createDatabase` and advances to `.installShortcut` (skipping field mapping).
  - [ ] Path B selection with a database that has all required fields resolves `FieldMapping` correctly.
  - [ ] Path B selection with a database missing `amountField` shows a validation error and does not advance.
  - [ ] OAuth cancellation (user dismisses `ASWebAuthenticationSession`) sets `viewModel.error = .oauthCancelled`.
  - [ ] `OnboardingViewModel.skipShortcut()` advances to the next step without calling any `NotionService` method.
  - [ ] After `completeOnboarding()`, `MockKeychainService.loadToken()` returns the stored token and `MockiCloudKVStoreService.load()` returns the `FieldMapping`.
- Integration tests:
  - [ ] OAuth flow with a real Notion integration token succeeds and saves to Keychain.
  - [ ] `NotionService.fetchDatabases()` returns the user's real databases during Path B.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- After completing onboarding (either path), `AppState.authStatus == .authenticated` and the main tab view is shown.
- Skipping optional steps (Shortcut, notifications) does not prevent onboarding from completing.
- Field mapping validation prevents proceeding without the three required field assignments.
