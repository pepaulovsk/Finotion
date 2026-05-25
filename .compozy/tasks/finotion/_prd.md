# Finotion — Product Requirements Document

## Overview

Finotion is a personal iOS application that eliminates the friction of personal finance record-keeping for a user who already manages their finances in Notion. It solves three problems: (1) logging expenses requires opening a separate app or doing it manually in Notion; (2) recurring payments (rent, subscriptions, insurance) are not automatically tracked and can be forgotten; (3) there is no quick way to see where spending stands mid-month without opening a Notion view.

Finotion integrates directly with an existing, organized Notion database. It adds zero infrastructure — no backend server, no third-party sync service. The app is the interface; Notion is the data store.

The product is a personal tool for a single user with no monetization in the MVP. The architecture should not preclude the possibility of adding a paywall in the future, even if the likelihood is low. There is no multi-user requirement.

---

## Goals

- Register any expense in under 10 seconds from trigger (NFC tap or app open) to confirmation.
- Automatically post recurring payments to Notion on their scheduled day, with no user action required.
- Surface a clear snapshot of monthly spending against personal goals from the moment the app opens.
- Keep the Notion workspace clean — category budget goals and recurring payment definitions are stored on-device and never written to Notion.

---

## User Stories

### Persona: Pedro — the sole user

Pedro is a knowledge worker who already uses Notion as his workspace. He tracks income and expenses in a Notion database with 8 fields. He has NFC stickers and uses Apple Shortcuts. His pain points are the friction of switching to an app to log a payment and the cognitive load of remembering which recurring charges have been logged each month.

**Setup and onboarding**
- As Pedro, I want to choose between starting from a ready-made Notion template or linking my existing database, so onboarding fits my situation without forcing me into a path that doesn't apply.
- As a new user, I want Finotion to create a template database in my Notion workspace so I can start tracking immediately without having to design a database structure myself.
- As Pedro (existing database), I want to connect Finotion to my existing Notion database and map each app concept (name, amount, type, category, etc.) to my actual property names, so the app works correctly regardless of what language or naming convention I used in Notion.
- As Pedro, I want the field mapping to be revisable from Settings at any time, so I can update it if I reorganize my Notion database.

**Expense capture**
- As Pedro, I want to tap an NFC sticker near my wallet and have an expense form appear pre-populated with date and payment method, so I can log a payment in seconds without unlocking my phone or opening an app.
- As Pedro, I want to register an expense manually inside the app using a floating '+' button, so I can log purchases when I don't have an NFC sticker available.
- As Pedro, I want a haptic and visual confirmation after an expense is saved, so I know it reached Notion without having to verify.

**Recurring payments**
- As Pedro, I want to define recurring payments (rent, Netflix, insurance, etc.) once, so that Finotion automatically posts them to Notion on their scheduled day each month.
- As Pedro, I want to see which recurring payments have been posted this month and which are still pending, so I always know my committed spend.
- As Pedro, I want a local notification when a recurring payment is auto-posted (or fails), so I am aware without having to open the app.
- As Pedro, I want to update the amount of a recurring payment, so that the new value is used from the current month forward while all entries already posted to Notion retain their original amounts.

**Dashboard**
- As Pedro, I want the home screen to show my total spending this month, a breakdown by category, and the status of recurring payments at a glance, so I can assess my financial position in under five seconds.
- As Pedro, I want to see a trend chart of spending by month, so I can identify patterns over time.
- As Pedro, I want a scrollable list of recent transactions pulled from Notion, so I can verify recent entries without leaving the app.

**Category budget goals**
- As Pedro, I want to set a spending limit per category for the current month, so the dashboard can show me how close I am to each limit.
- As Pedro, I want the goals I set this month to carry forward automatically next month, so I don't have to reconfigure them every 30 days.
- As Pedro, I want to adjust any goal for the current month without it affecting other months, so my limits stay realistic as my life changes.

**Merchant aliases**
- As Pedro, I want to assign a friendly alias to any merchant name (e.g., "Padaria" for "Renata Pascolli Sousa"), so that Notion always shows the alias instead of the raw terminal name.
- As Pedro, I want the app to apply aliases automatically when I register any expense whose raw merchant name is already in my alias list, so I never have to think about it.
- As Pedro, I want to see a list of merchants that have appeared in my expenses but don't yet have an alias, so I can clean up my Notion data at my own pace without interrupting the registration flow.

**Data persistence**
- As Pedro, I want all my app data (Notion connection, recurring payments, category goals, and merchant aliases) to be automatically restored if I delete and reinstall the app, so I never have to reconfigure everything from scratch.
- As Pedro, I want this persistence to happen through my Apple ID, with no separate Finotion account or password required.

---

## Core Features

### 1. Expense Registration

The primary action in Finotion. Users register an expense by providing: amount (required), category (required), payment method (optional), date (defaults to now), and description (optional). The transaction is posted directly to the user's existing Notion database.

Two entry paths exist:
- **NFC + Apple Shortcut**: an NFC sticker triggers a Shortcut that opens a pre-filled form in Finotion. Date and payment method are auto-populated. The user provides amount and category, then confirms.
- **Manual entry**: a floating '+' button on the home screen opens the same form.

After saving, the app shows a toast and fires a haptic response. The new transaction appears in the home screen list on the next refresh.

Categories are fetched from the Notion database's Category select field. The app refreshes the category list when the screen opens, when the app returns to the foreground, and on pull-to-refresh. Users can create a new category directly in the form; the new option is pushed to Notion's select field immediately.

### 2. Recurring Payments

A module for fixed, predictable monthly charges: rent, streaming, utilities, insurance, gym, loan installments, etc. These are distinct from ad-hoc expenses — they are scheduled, named, and automatically posted.

Each recurring payment record includes: name, amount, due day of month (1–31), category, payment method, and active/inactive toggle. Records are stored locally in the app (CoreData) and are not written to Notion directly — only the generated expense entries are posted.

**Value versioning**: when the user edits the amount of a recurring payment, the new value applies to the current month's dispatch and all future dispatches. Entries already posted to Notion in previous months are immutable — they retain the amount that was valid at the time of posting. This ensures the historical record in Notion is accurate.

**Automatic dispatch**: The app uses iOS BackgroundTasks to run a daily check. If today's date matches a payment's due day, and no entry for that payment+month already exists in Notion (deduplication check), the app creates an expense entry in Notion automatically.

**Manual dispatch**: The user can open the Recurring Payments screen and trigger any pending payment manually.

The home screen dashboard shows a "Recurring this month" section: payments posted (with amounts) and payments still pending (with their due dates).

### 3. Dashboard

The home screen. Loads on app open with data fetched from Notion. A pull-to-refresh gesture forces a new fetch.

Sections:
- **Month header**: current month name, total spent, and a progress ring showing total vs. a configurable overall limit (optional).
- **Category breakdown**: each category with amount spent and, if a goal is set, a progress bar (e.g., "Alimentação: R$ 620 / R$ 800").
- **Recurring payments status**: compact list of this month's recurring payments — paid (with date) and pending (with due date and amount).
- **Transaction history**: paginated list of recent transactions (up to 60 days), fetched from Notion in descending date order.
- **Spending over time**: a visualization of total spending across the last several months, enabling the user to identify trends and seasonal patterns.
- **Category spending visualization**: a visualization of spending per category for the current month, showing the amount spent alongside the configured limit for each category (where set), making it easy to compare actual vs. target at a glance.

The floating '+' button is always visible, overlaying the dashboard, to allow immediate expense entry without scrolling.

### 4. Merchant Aliases

A dictionary that maps raw merchant names (as received from payment terminals via Apple Shortcuts) to user-defined friendly names. When Finotion posts an expense to Notion, it checks whether the merchant name matches any entry in the alias dictionary. If a match is found, the alias is used as the Name field in Notion. If no match exists, the raw merchant name is posted as-is.

**Management screen**: a dedicated view (accessible from Settings) lists all known merchants — split into two sections:
- **Named merchants**: those with an alias set, showing both the raw name and the alias. Tapping allows editing the alias.
- **Unnamed merchants**: raw merchant names that have appeared in the user's expenses but have no alias yet. These are surfaced as a gentle nudge — no badge, no alert, just a visible list the user can address at their convenience.

When a new, unrecognized merchant appears in an expense registration, the transaction is saved to Notion with the raw name immediately (zero friction). The merchant is added to the unnamed list in the background. No interruption occurs during the registration flow.

Aliases apply retroactively only in the app's display — entries already in Notion are not updated. New and future entries for that merchant will use the alias.

### 5. Category Budget Goals

Users set a monthly spending limit per category. Goals are stored on-device (CoreData), keyed by category name and year-month. They are never written to Notion.

**Auto-carry**: at the start of each new month, the previous month's goals are automatically copied forward. The user can adjust any goal at any time; adjustments apply only to the current month.

The dashboard uses goal data to render progress bars alongside each category's spend. When spending exceeds 90% of a goal, the progress bar turns amber. When it exceeds 100%, it turns red.

### 6. Onboarding

A guided flow presented to first-time users. At step 2, the user chooses between two paths that diverge and then rejoin at the final steps.

**Step 1 — Connect to Notion**: OAuth 2.0 authentication via `ASWebAuthenticationSession`. The access token is stored in iCloud Keychain.

**Step 2 — Choose a database path**: the user selects one of two options:

- **Path A — Start from a template**: Finotion creates a ready-made database in the user's Notion workspace with a predefined structure and placeholder content. The user can rename and customize it freely in Notion. No field mapping is required — Finotion knows the structure because it created it. Best for users who don't yet have a finance database in Notion.
- **Path B — Use an existing database**: the app lists available Notion databases in the workspace. The user selects their existing finance database, then maps each app concept (transaction name, amount, type, category, payment method, date, reference date) to the matching property. Properties that don't exist can be skipped; features relying on skipped fields will be disabled. Best for users who already track finances in Notion.

**Step 3 — Install Apple Shortcut** *(skippable)*: a deep link opens the Shortcuts app with a pre-configured expense-entry shortcut that can be bound to an NFC sticker. The user taps "Add Shortcut".

**Step 4 — Enable notifications** *(skippable)*: the app requests notification permission for recurring payment alerts. The user is shown why the permission is needed before the system dialog appears.

Skipped steps (3 and 4) can be completed later from Settings. Field mapping (Path B) is required to proceed and can also be revised later from Settings.

---

## User Experience

### Home Screen (Hybrid Dashboard)

The home screen is the app's center of gravity. It opens instantly with cached data from the previous session, then silently refreshes from Notion in the background. A loading indicator appears only when no cached data is available.

The floating '+' button sits at the bottom-right of every screen, providing one-tap access to the expense form regardless of scroll position or current tab.

### Expense Entry Form

A bottom sheet modal. Fields in order: Amount (numeric keyboard, auto-focused), Category (search-as-you-type from Notion categories), Payment Method (segmented control), Date (defaults to now, tappable to change), Description (optional, collapsed by default). A "Save" button is active as soon as Amount and Category are filled.

### Recurring Payments Screen

A list view with two sections: Active and Inactive. Each row shows name, amount, and due day. Tapping opens an edit form. A "Run pending" button at the top manually triggers all overdue payments for the current month.

### Merchant Aliases Screen

Accessible from Settings. Two sections: "Named" (alias set) and "Unnamed" (raw names waiting for an alias). Each named row shows the raw terminal name and the alias below it. Each unnamed row shows only the raw name with an "Add alias" affordance. No badge or alert draws attention to unnamed merchants — it's a passive, non-urgent list.

### Settings Screen

Covers: connected Notion workspace (with disconnect option), selected database (with change option), Apple Shortcut re-install link, notification permissions status, merchant alias management, and category goal management.

### iCloud Sync Behavior

All user data syncs automatically via iCloud under the user's Apple ID. No Finotion account or password exists. On reinstall, the app detects the iCloud sync state and restores:
- The Notion OAuth token (via iCloud Keychain)
- Recurring payment definitions
- Category budget goals
- Merchant alias dictionary

If iCloud is unavailable or disabled, the app works locally and displays a non-blocking notice that data won't persist across reinstalls.

---

## High-Level Technical Constraints

- **iOS 16 minimum**: required for Swift Charts (native chart library used for spending visualizations).
- **Notion API**: all financial data reads and writes go through Notion's official REST API. No custom backend server is involved at any point.
- **OAuth 2.0**: Notion authentication uses the official OAuth flow. The access token is stored exclusively in the iOS Keychain and is never logged or transmitted to any party other than Notion.
- **BackgroundTasks**: recurring payment dispatch uses the iOS BackgroundTasks framework. The system controls when background tasks run; the app registers a task and handles the case where it does not run exactly at midnight.
- **No data leaves the device to any server**: all local state (goals, recurring payment definitions) is stored on-device. No analytics, crash reporting, or telemetry is sent anywhere.
- **Two onboarding database paths**: Finotion can either create a template database in the user's Notion workspace (Path A) or connect to an existing database with user-defined field mapping (Path B). Both paths are fully supported.
- **No assumed field names**: Finotion does not hardcode Notion property names. All field references are resolved through the user-defined mapping set up during onboarding. A user whose database uses "Valor", "Data", "Categoria" (or any other language or naming convention) gets the same experience as a user with English field names.
- **Future-proofed for monetization**: the codebase should use a feature-access abstraction layer from day one so that, if a paywall is ever introduced, features can be gated without structural changes.
- **iCloud as the identity and sync layer**: the user's Apple ID is the sole identity in Finotion. User data (Notion token, recurring payments, goals, merchant aliases) is synced via iCloud so it survives app deletion and reinstall. No Finotion account or backend authentication is required.

---

## Non-Goals (Out of Scope)

**Out of MVP — deferred to Phase 2 or later:**
- Nubank notification capture (confirm/edit flow via NotificationServiceExtension)
- Income / earnings tracking and entry
- Support for banks other than Nubank (Itaú, Inter, C6, etc.)
- Multiple Notion workspaces
- Report export (PDF, CSV)
- Widgets (Lock Screen, Home Screen)
- Apple Watch companion app

**Out of scope permanently (for this personal tool):**
- Android or web versions
- Direct bank API integration (Open Finance)
- Multi-user or shared expense tracking
- AI-powered auto-categorization

---

## Phased Rollout Plan

### Phase 1 — MVP

**Core features:**
- Onboarding (all 5 steps, including field mapping)
- Expense registration via NFC + Shortcuts and manual entry
- Recurring payments (CRUD + automatic daily dispatch + manual trigger + value versioning)
- Dashboard (month total, category breakdown with goals, recurring status, transaction history, spending visualizations)
- Category budget goals (iCloud-synced, auto-carry monthly)
- Merchant aliases (iCloud-synced dictionary with zero-friction registration flow)
- iCloud sync for all user data (survives reinstall without re-authentication)

**Success criteria to proceed to Phase 2:**
- All core features work end-to-end without crashes
- NFC → expense → Notion round-trip completes in under 15 seconds
- Recurring payments auto-dispatch correctly for at least one full billing cycle
- Dashboard loads from cache within 2 seconds and reflects accurate data after background refresh

### Phase 2

**Additional features:**
- Nubank notification capture: confirm/edit flow via NotificationServiceExtension
- Income tracking: manual entry of earnings (salary, freelance, etc.) posted to Notion using the mapped Type field
- Loan management: a dedicated screen to track money lent and repaid, using the mapped Reference Date field and the user's loan-related categories (e.g., "Borrow" and "Payback"). Shows outstanding balances by person, monthly lending and repayment totals, and history. Full feature scope to be defined before implementation.
- Home Screen widget: small widget showing month total and top categories at a glance

**Success criteria to proceed to Phase 3:**
- Income entries appear correctly in the dashboard totals
- Nubank charge notifications are captured and result in a Notion entry with fewer than 5% requiring manual correction
- Loan management screen correctly aggregates lending and repayment data from Notion

### Phase 3

**Full feature set:**
- Multi-workspace support: connect to a second Notion workspace (e.g., business expenses)
- Report export: generate a monthly PDF or CSV summary from the dashboard
- Lock Screen widget: spending total or today's transactions visible without unlocking

---

## Success Metrics

Since Finotion is a personal tool, success is measured by personal workflow outcomes:

- **Capture speed**: an expense is registered in Notion within 10 seconds of tapping the NFC sticker.
- **Recurring reliability**: zero missed recurring payments over any 30-day period once configured.
- **Dashboard load time**: home screen shows data within 2 seconds of app open (using cached data while refreshing in background).
- **Daily active use**: the app is the primary interface for logging expenses — Notion is opened for expenses only for ad-hoc analysis, not for data entry.

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Notion API downtime prevents expense registration | Low | High | Show a clear error with a retry option. Queue failed entries locally and retry on next app open. |
| iOS BackgroundTasks throttles or skips the recurring payment check | Medium | Medium | Provide a visible "Run pending" manual trigger on the Recurring screen. Notify the user if a payment's due date has passed without dispatch. |
| NFC sticker setup is too complex for initial onboarding | Low | Medium | Make the Shortcut install step skippable. Provide a brief in-app guide with photos. Default the manual entry flow as the fallback. |
| Notion database schema mismatch during field mapping (Path B) | Medium | Medium | The field mapping screen shows all available properties in the database and lets the user skip any that don't exist. Features that depend on skipped fields are disabled with a clear explanation. |
| iCloud unavailable (user disabled iCloud or has no storage) | Low | Medium | App works fully in local-only mode. Display a persistent but non-blocking banner informing the user that data will not survive reinstall. |
| Merchant alias dictionary grows large over time | Low | Low | The alias screen supports search. No limit on the number of entries is needed for a personal tool. |

---

## Architecture Decision Records

- [ADR-001: Product Approach — Notion Finance Companion](adrs/adr-001.md) — Finotion is a lightweight iOS companion to an existing Notion workspace, not a standalone finance hub. Notion is the single source of truth; the app focuses on zero-friction capture and a contextual dashboard.

---

## Open Questions

- **Ref. Date field in the expense form**: if the user maps a reference date field during onboarding, should it appear in the expense entry form by default, or only as an optional advanced field the user can expand? The answer likely depends on whether the user actively uses Ref. Date in their Notion views.
- **Notion category stale state**: if Finotion fetches categories and then the user adds a category directly in Notion before the next app refresh, the app's local category list will be stale. The current design handles this with pull-to-refresh and foreground refresh — confirm this is acceptable or if an explicit "Sync categories" action in Settings is also needed.
