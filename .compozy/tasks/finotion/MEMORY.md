# Finotion — Workflow Memory

## Current State

- Task 01 (Xcode Project Scaffold): **completed**
- All other tasks: pending

## Shared Decisions

- **XcodeGen as project generator**: The `.xcodeproj` is generated from `Finotion/project.yml` using XcodeGen. Run `xcodegen generate` inside `Finotion/` on macOS before opening in Xcode. Source files are the single source of truth — the generated `.xcodeproj` is a build artifact and should be gitignored or regenerated as needed.
- **iOS 17.0 minimum**: As per ADR-002. SwiftData + @Observable macro. No CoreData.
- **CloudKit container**: `iCloud.com.finotion.app` — must match exactly in `Finotion.entitlements` and in the `ModelConfiguration` added in task_03.
- **Bundle ID**: `com.finotion.app`
- **Background task identifier**: `com.finotion.recurring-dispatch` — registered in Info.plist `BGTaskSchedulerPermittedIdentifiers`.
- **URL scheme**: `finotion` — registered in Info.plist `CFBundleURLSchemes`.
- **SwiftLint**: configured as a preBuildScript in `project.yml`; `.swiftlint.yml` at `Finotion/` root. `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` for all configurations.

## Shared Learnings

- Build and simulator verification (task_01 subtask 1.5 and integration tests) requires macOS + Xcode. All source and config files are created; `xcodegen generate` must be run on macOS to produce the `.xcodeproj` before building.
- Keychain entitlement uses `$(AppIdentifierPrefix)` which expands to the Team ID at build time — no hardcoded Team ID needed.
- iCloud KV Store entitlement uses `$(TeamIdentifierPrefix)` prefix pattern.
- Background modes (`fetch`, `remote-notification`) belong in `UIBackgroundModes` in Info.plist, NOT in the entitlements file.

## Open Risks

- Apple Developer account with CloudKit + BackgroundTasks capabilities must be activated before running on a real device. Simulator testing does not require this.
- Notion OAuth credentials (client ID + secret) needed before task_06 (Onboarding flow).

## Handoffs

- task_02: depends on project existing; add `NotionService` protocol and `MockNotionService` under `Services/`.
- task_03: must use `cloudKitContainerIdentifier: "iCloud.com.finotion.app"` in `ModelConfiguration`.
- task_04: `KeychainService` goes under `Services/`; use `kSecAttrSynchronizable = true`.
