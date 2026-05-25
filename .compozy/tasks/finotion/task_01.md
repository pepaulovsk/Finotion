---
status: completed
title: Xcode Project Scaffold
type: infra
complexity: medium
dependencies: []
---

# Task 1: Xcode Project Scaffold

## Overview
Creates the Xcode project skeleton for Finotion with all required system capabilities, entitlements, and folder structure in place. This task produces no user-visible features but is the prerequisite for every subsequent task — no code can be written until the project is properly configured.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST create a SwiftUI App target with iOS 17.0 as the minimum deployment target.
- MUST enable the following capabilities in the target's entitlements: iCloud (CloudKit + iCloud Key-Value Storage), Background Modes (Background fetch + Remote notifications), Keychain Sharing.
- MUST register the URL scheme `finotion` in Info.plist so the app can be launched by Apple Shortcuts.
- MUST add the Background Tasks usage entry (`BGTaskSchedulerPermittedIdentifiers`) to Info.plist with value `com.finotion.recurring-dispatch`.
- MUST establish the folder structure defined in the TechSpec System Architecture section: `Features/`, `Services/`, `Core/`, `Models/`.
- MUST configure the CloudKit container identifier (`iCloud.com.finotion.app`) in entitlements.
- SHOULD configure SwiftLint (or equivalent) as a build phase to enforce consistent code style from the first commit.
</requirements>

## Subtasks
- [x] 1.1 Create a new Xcode project (SwiftUI App, Swift, iOS 17.0 deployment target, no Core Data checkbox — SwiftData is added manually in task_03).
- [x] 1.2 Configure entitlements file: iCloud (enable CloudKit + KV), Keychain Sharing (app group `com.finotion.app`), Background Modes (background fetch, remote notifications).
- [x] 1.3 Add Info.plist entries: `CFBundleURLSchemes` (`finotion`), `BGTaskSchedulerPermittedIdentifiers` (`com.finotion.recurring-dispatch`), `NSUserNotificationUsageDescription`.
- [x] 1.4 Create the top-level folder groups in Xcode: `Features/`, `Services/`, `Core/`, `Models/`.
- [ ] 1.5 Verify the project builds cleanly on the iOS 17 simulator with no warnings. *(requires macOS — run `xcodegen generate` then build in Xcode)*

## Implementation Details
See TechSpec "System Architecture" and "Integration Points — BackgroundTasks" sections for the full list of entitlements and Info.plist keys required.

The CloudKit container identifier must match exactly between the entitlements file and the `ModelConfiguration` that will be added in task_03.

### Relevant Files
- `Finotion/Finotion.entitlements` — entitlements file (to create)
- `Finotion/Info.plist` — URL scheme and background task registration (to create/modify)
- `Finotion/FinotionApp.swift` — app entry point (to create)

### Dependent Files
- All subsequent task files depend on the project existing and building cleanly.
- `task_03` will add the CloudKit container identifier referenced here.
- `task_07` will implement the URL scheme handler registered here.
- `task_09` will register the Background Task identifier registered here.

### Related ADRs
- [ADR-002: iOS 17 Minimum and SwiftData](../adrs/adr-002.md) — Determines the deployment target and required capabilities.

## Deliverables
- Xcode project at `Finotion/Finotion.xcodeproj` with iOS 17 target, all entitlements, and URL scheme registered.
- Top-level folder groups created in Xcode project navigator.
- Project builds and runs on iOS 17 simulator with no errors or warnings.
- Unit tests with 80%+ coverage **(REQUIRED)** — for this task, a baseline `FinotionTests` target must exist and the default generated test must pass.

## Tests
- Unit tests:
  - [ ] Default XCTest target exists and the generated `testExample` test passes.
  - [ ] Build succeeds with no warnings (treat warnings as errors via `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` in Debug configuration).
- Integration tests:
  - [ ] App launches on iOS 17.0 simulator without crashing.
  - [ ] URL scheme `finotion://` can be opened from Safari on the simulator (redirects to app).
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Project compiles cleanly on iOS 17 simulator.
- All required entitlements and Info.plist keys are present and correctly spelled.
- Folder structure matches TechSpec System Architecture section.
