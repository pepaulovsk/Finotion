---
status: pending
title: KeychainService and iCloud Configuration
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 4: KeychainService and iCloud Configuration

## Overview
Implements the two iCloud-backed storage layers that give Finotion its "no login required after reinstall" property: the iCloud Keychain (for the Notion OAuth token) and `NSUbiquitousKeyValueStore` (for the `FieldMapping` configuration). Also defines the `FieldMapping` `Codable` struct. Every feature that touches the Notion API or reads the field mapping depends on the outputs of this task.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST implement `KeychainService` with `save(token:)`, `loadToken() -> String?`, and `deleteToken()` methods targeting the key `"notion_access_token"` with `kSecAttrSynchronizable = true` and `kSecAttrAccessibleAfterFirstUnlock`.
- MUST implement an `iCloudKVStoreService` (or equivalent wrapper) with `save(_: FieldMapping)`, `load() -> FieldMapping?`, and `clear()` methods backed by `NSUbiquitousKeyValueStore.default`.
- MUST define `FieldMapping` as a `Codable`, `Equatable` struct with all fields from the TechSpec "Core Interfaces" section.
- `FieldMapping` optional fields (`typeField`, `categoryField`, `paymentMethodField`, `refDateField`) MUST be truly optional (`String?`) so users can skip them during onboarding without breaking encoding/decoding.
- `iCloudKVStoreService` MUST call `NSUbiquitousKeyValueStore.default.synchronize()` on app foreground — the hook for this is registered in task_05.
- `KeychainService` MUST NOT store the raw token in `UserDefaults` or any non-Keychain location.
- Both services MUST be injectable via protocols to allow mock implementations in tests.
</requirements>

## Subtasks
- [ ] 4.1 Define `Models/FieldMapping.swift` with the `Codable, Equatable` struct.
- [ ] 4.2 Create `Services/Keychain/KeychainServiceProtocol.swift` and `Services/Keychain/KeychainService.swift` implementing iCloud Keychain storage.
- [ ] 4.3 Create `Services/Config/iCloudKVStoreService.swift` wrapping `NSUbiquitousKeyValueStore` for `FieldMapping` persistence.
- [ ] 4.4 Create `Services/Config/MockiCloudKVStoreService.swift` and `Services/Keychain/MockKeychainService.swift` for use in tests and Previews.
- [ ] 4.5 Write unit tests for `FieldMapping` encode/decode round-trips and for mock service behaviors.

## Implementation Details
See TechSpec "Core Interfaces — FieldMapping" for the full struct definition and "Data Models — Configuration" table for KV store keys.

For unit tests, use the mock service implementations — do not write to the real Keychain or iCloud KV store in tests, as those require device-level entitlements.

The `iCloudKVStoreService` stores `FieldMapping` as JSON under the key `"fieldMapping"` in `NSUbiquitousKeyValueStore`. The `synchronize()` call in app foreground is wired in task_05.

### Relevant Files
- `Finotion/Models/FieldMapping.swift` — Codable struct (to create)
- `Finotion/Services/Keychain/KeychainService.swift` — iCloud Keychain wrapper (to create)
- `Finotion/Services/Config/iCloudKVStoreService.swift` — NSUbiquitousKeyValueStore wrapper (to create)
- `Finotion/Services/Keychain/MockKeychainService.swift` — test mock (to create)
- `Finotion/Services/Config/MockiCloudKVStoreService.swift` — test mock (to create)
- `FinotionTests/Services/KeychainServiceTests.swift` — unit tests (to create)

### Dependent Files
- `task_05` (AppState) reads `FieldMapping` on app launch to determine auth/onboarding state.
- `task_06` (Onboarding) writes `FieldMapping` after the user completes field mapping.
- `task_12` (LiveNotionService) reads the Keychain token for all API requests.

### Related ADRs
- [ADR-002: iOS 17 Minimum and SwiftData](../adrs/adr-002.md) — Explains why `NSUbiquitousKeyValueStore` is used for FieldMapping instead of SwiftData (lightweight, no CloudKit schema).

## Deliverables
- `Models/FieldMapping.swift` with full struct definition.
- `Services/Keychain/KeychainService.swift` (real) and `MockKeychainService.swift` (test).
- `Services/Config/iCloudKVStoreService.swift` (real) and `MockiCloudKVStoreService.swift` (test).
- Unit tests with 80%+ coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `FieldMapping` with all optional fields set encodes to JSON and decodes back with identical values.
  - [ ] `FieldMapping` with all optional fields `nil` encodes to JSON and decodes back without crashing.
  - [ ] `MockKeychainService.save(token:)` stores the token; `loadToken()` returns it; `deleteToken()` makes `loadToken()` return `nil`.
  - [ ] `MockiCloudKVStoreService.save(_:)` stores a `FieldMapping`; `load()` returns it; `clear()` makes `load()` return `nil`.
  - [ ] `iCloudKVStoreService` (mock) with a corrupted JSON value stored at `"fieldMapping"` returns `nil` from `load()` without crashing.
  - [ ] Two `FieldMapping` instances with identical values are equal (`Equatable`).
- Integration tests:
  - [ ] `KeychainService` (real) on device: save and load token in the same app session (requires physical device or simulator with Keychain entitlement).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- No token or config data is ever written to `UserDefaults` or any non-secure location.
- Mock implementations allow all dependent tasks (05, 06, 12) to be built without real iCloud or Keychain access.
