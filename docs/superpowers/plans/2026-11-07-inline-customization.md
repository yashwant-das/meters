# Inline Customization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Customize the live popover in place, make usage colors optional, and remove unused bottom space.

**Architecture:** Keep SystemMonitor and StatsView mounted. Share transient customization state with AppDelegate for Command-comma and reopen behavior. Measure the scroll content and header/footer to size the popover within the status item's screen; native SwiftUI preferences persist appearance changes.

**Tech Stack:** SwiftUI, AppKit, ServiceManagement; macOS 14+; no dependencies.

**Spec:** `docs/superpowers/specs/2026-11-07-inline-customization-design.md` (approved by user).

## Global Constraints

- Preserve all three layouts, all three menu styles, and existing preferences.
- Keep header/footer accessible; use scrolling only above the available height.
- Usage colors default on; charts and thermal colors remain independent.
- Keep monitoring/history alive while customizing. Native light/dark controls.

## Review Focus

- Short screens and expanded compact disclosures must not clip footer or controls (Task 2 native harness).
- Repeated toggles and layout changes must resize down as well as up without oscillation (Task 2 harness).
- Missing readings and 60/80% boundaries must retain formatting with colors off (Task 1).
- Command-comma and reopen must reach the same section without recreating monitoring (Task 2 app check).
- Login approval/error handling and preview preference isolation must survive the move (Task 2 code review/preview check).

### Task 1: Persist and render optional usage colors

**Files:** `meters/AppearancePreferences.swift`, `meters/MenuBarRenderer.swift`, `tests/AppearanceTests.swift`.

**Interfaces:** `Prefs.usageColorsKey`; `MenuBarRenderer.title(cpu:ram:gpu:style:usageColors:)` defaults `usageColors` to true.

- [x] Add assertions for new-default-on, preserved-off migration, and actual title foreground colors at nil, 59, 60, 80, 100 in every style and appearance. Ensure disabling colors preserves width.
- [x] Run appearance tests to demonstrate the missing interface/behavior, then implement the preference and renderer flag including micro-meter fills.
- [x] Run the full appearance tests and monitoring calculation tests.

### Task 2: Inline settings and measured popover layout

**Files:** `meters/AppearanceSettingsView.swift`, `meters/StatsView.swift`, `meters/MetersApp.swift`, `meters/UIPreviews.swift`, new `meters/PopoverPresentation.swift`, `tests/PopoverPresentationTests.swift`.

**Interfaces:** `PopoverPresentation` observable state (`customizing`, `maximumHeight`, `openCustomization()`, `reset()`); pure `PopoverSizing.height(content:chrome:available:)` helper. `StatsView` accepts the shared presentation and an optional size-change callback.

- [x] Add sizing tests for fitting content, overflow, shrink, and invalid measurements; run red, implement helper, run green.
- [x] Replace window-sized settings with a compact Customize card: pickers, usage toggle/helper text, Done, and login handling.
- [x] Split StatsView into fixed header/footer and measured scroll content. Report fitted size and preserve layout/disclosure state while settings change. Scroll to Customize when opening it.
- [x] Remove settings-window creation and fixed layout heights from AppDelegate; route settings commands into the shared state, refresh available screen height on show, and reset customization on close.
- [x] Update previews to show inline customization light/dark using isolated defaults.
- [x] Use a temporary native harness to exercise expanded/collapsed sizing for each layout, short screens, disclosures, and layout switching; inspect light/dark renders. Verify Command-comma/reopen routing and history identity in app integration code.

### Task 3: Verification and documentation

**Files:** `README.md`, spec, this plan.

- [x] Describe inline customization, optional menu colors, adaptive size, and updated Canvas previews.
- [x] Run all standalone test executables, Debug/Release builds, and `git diff --check`.
- [x] Review the full diff against the spec and document validation/limitations. Leave changes ready for review; no automatic push.


## Results

- Standalone appearance tests pass: default-on migration, explicit opt-out, all styles/appearances, boundary and unavailable values, stable widths, and rendered micro-meter fills.
- Monitoring data and popover presentation tests pass. Presentation regression covers repeated Customize requests while already expanded.
- Native rendered sizing checks pass for all three layouts in both appearances. Collapsed heights with representative fixture readings: grouped 653 pt, compact 486 pt, activity 646 pt. Customize adds 260 pt; a 420 pt cap is respected and content shrinks again when collapsed.
- Actual AppDelegate integration verifies status-popover sizing, inline settings, layout changes, retained host/history, and close/reset/reopen. Temporary app identifiers isolate review preferences from the installed app.
- Native UI checks verify compact disclosures, Command-comma, layout/style selection, usage toggle, and fixed footer accessibility. Review identified an already-expanded Customize reveal bug; a request counter fixes it, with a regression test and native scroll-to-top confirmation for footer/keyboard commands.
- Debug and Release builds pass. Only the existing AppIntents metadata-skipped build note remains. Diff whitespace check passes.
- Login registration itself was not changed during UI review; existing approval/error behavior is preserved.
- Changes prepared for PR review at the user’s request; no release performed. Figma is deferred until after release; prompt the user before syncing all recent changes.

Ruling: keep the current feature checkout and leave changes available for review; no additional worktree or integration approval is needed to implement the authorized design.
