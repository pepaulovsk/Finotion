---
name: task-05-appstate-di-root
description: Decisions and learnings from task_05 — AppState, Dependency Injection Root, CategoryService
metadata:
  type: project
---

## Decisions

- **`@Observable AppState` with injectable services**: `AppState` receives `KeychainServiceProtocol` and `iCloudKVStoreServiceProtocol` in its `init` (with real service defaults). This makes the class fully testable without real Keychain/iCloud access.
- **`AuthStatus: Equatable`** added in main module (`AppState.swift`) so tests can use `XCTAssertEqual` without retroactive conformance in the test target.
- **scenePhase observer in `RootView`**: `NSUbiquitousKeyValueStore.default.synchronize()` and `appState.reloadFieldMapping()` are called from `.onChange(of: scenePhase)` inside `RootView` (not the `App` struct). The KV change notification is also in `RootView` via `.onReceive`.
- **`CategoryService.addCategory` takes `propertyId:`**: The underlying `NotionService.addCategoryOption` requires the Notion property ID. Callers (task_07, task_09) must supply it from the `FieldMapping`.
- **Environment keys use `EnvironmentKey` protocol** (not `@Entry` macro — iOS 18 only). `NotionService` stored as `any NotionService`; `CategoryService` stored directly (it's a class).
- **`ModelContainer` fallback**: `FinotionApp` tries CloudKit container first, falls back to in-memory if it throws (CI simulator without entitlements). Production device will use CloudKit.
- **`ContentView.swift` left intact**: No longer referenced by `FinotionApp`; unused `View` structs don't cause warnings in Swift.

## Learnings

- `@Observable` only tracks `var` stored properties; `let` dependencies (injected services) are ignored by the macro — correct behavior, no workaround needed.
- `any Protocol` existentials work fine as stored properties in `@Observable` classes when the held type is a reference type (class).
- Sorted imports (SwiftLint rule): `SwiftData` before `SwiftUI` alphabetically.
