# Meters Appearance Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship all six approved presentations with independent persistent settings.

**Architecture:** Foundation-only preference and formatting types; AppKit status rendering; native SwiftUI statistics and settings views. Preserve the existing SystemMonitor and data calculations.

**Tech Stack:** Swift, SwiftUI, AppKit, Charts, UserDefaults, ServiceManagement.

**Spec:** `docs/superpowers/specs/2026-11-05-appearance-design.md`

## Global Constraints
- macOS 14+, native SwiftUI, no dependencies.
- Independent layout/style preferences, existing icon-mode migration.
- Keep existing metrics, optional values, history gaps, 2-second sampling and warning thresholds.
- Preserve existing uncommitted work; leave changes reviewable, without automatic commits.

## Review Focus
- First launch, old icon preference, invalid persisted values: sensible migration/defaults.
- 0/100/unavailable/nonfinite readings: stable menu width and safe bar bounds.
- All nine combinations: preferences apply independently and immediately.
- Compact expansion/smaller screens: details remain reachable without clipping.
- Login registration failure or pending approval: show truthful state and actionable feedback.

### Task 1: Preferences and menu rendering
Files: `meters/AppearancePreferences.swift`, `meters/MenuBarRenderer.swift`, `tests/AppearanceTests.swift`, `meters/MetersApp.swift`.
Interfaces: `PopoverLayout`, `MenuBarStyle`, `Prefs.migrate(in:)`, `MenuBarPresentation`, `MenuBarRenderer.title(cpu:ram:gpu:style:)`.
- [x] Add failing migration, independent persistence, safe-formatting, fixed rendered-width, style attachment and threshold tests.
- [x] Run tests, implement types/renderer and rerun.
- [x] Connect status item updates to persisted style changes.

### Task 2: Native popovers and settings
Files: `meters/StatsView.swift`, `meters/AppearanceSettingsView.swift`, `meters/MetersApp.swift`.
Interfaces: `StatsView(monitor:openSettings:)`, `AppearanceSettingsView`.
- [x] Implement all layouts using shared editable native views and SF Symbols; native Charts preserve missing samples.
- [x] Build native settings with independent radio choices, persisted defaults, and login feedback.
- [x] Wire Settings button to one reusable native window; refresh/rescale popover on layout changes.
- [x] Compile Debug and Release and run all calculation/presentation tests.

### Task 3: Verification and documentation
Files: `README.md`; temporary UI verification harness under `/tmp`.
- [x] Render real SwiftUI views in both appearances and exercise settings/compact disclosures.
- [x] Review edge cases, run all tests and whitespace check, update README.
- [x] Record validation, limitations and any deviations below.

## Progress
- Plan/spec recorded; implementation authorized by “Proceed to build it”.
- Reused the existing dirty checkout to preserve monitoring work; no automatic commits or integration.
- Appearance tests caught unavailable-reading width changes. ASCII padding with the native monospaced font and disabled kerning/ligatures keeps all rendered widths stable.
- Native test app verified layout switching, independent style selection, both appearances, and compact expansion/scrolling without touching the installed app's preferences. Eight offscreen snapshots cover all layouts plus settings in light/dark.
- The initial source review found no important bugs. A final whole-change review identified Canvas lifecycle writes and nominal chart timing; both were reproduced and fixed before commit. The Canvas lifecycle guard leaves standard preferences untouched, and history now retains actual sample times within a two-minute window. Monitoring timers are invalidated on teardown.
- Deferred minor checks: isolated history samples after missing readings may be invisible until another valid sample, and moving a live popover between differently sized displays needs additional verification. Settings' illustrative menu preview uses SwiftUI rather than the AppKit renderer. Automated nine-combination coverage checks preference persistence; native UI interactions were verified for each layout and style rather than every pair.
- Xcode builds require permission for SwiftUI compiler plugins outside the filesystem sandbox. No product dependencies or deployment settings were changed.
