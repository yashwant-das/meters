# Inline customization and content-sized popover

## Intent

Keep Meters native to macOS while letting users see appearance changes immediately in the same popover. Remove unused space below its footer and make usage-based menu bar colors optional.

## Approaches

- **Expandable Customize section above the dashboard — selected by the user.** Keeps the actual readings and their appearance visible during editing. Expanded content can require scrolling on shorter screens.
- **Settings page inside the popover.** Provides more room for controls, but hides the dashboard or requires a duplicate preview. Not selected.
- **Separate settings window — current behavior.** Has plenty of space but disconnects changes from their effect. Replace this path with inline customization.

## Proposed interaction

- A small native gear button in the header toggles Customize. The existing footer action and Command-comma open the same section.
- Customize uses compact, labeled native pickers for panel layout and menu bar style. Preserve all three layouts, all three styles, and existing preferences.
- A Done button collapses the section. The dashboard stays mounted, continues sampling, and retains history while settings change.
- Changes apply directly to the actual dashboard and status title. No Apply button or simulated preview is needed in production.
- Keep launch at login, including its current error and macOS approval handling, in a visually separate group within Customize.
- Proposal: reopen the popover with Customize collapsed for a predictable monitoring view; saved appearance choices persist.

## Usage-color preference

- Add **Color readings by usage**, enabled by default to preserve current behavior.
- Enabled: percentages and micro-meter fills use the existing thresholds (normal below 60%, orange from 60%, red from 80%).
- Disabled: percentages and micro-meter fills use the native adaptive label color. Labels and symbols retain their existing appearance.
- Explain the thresholds next to the toggle. This preference does not change chart series colors or thermal-state colors and does not claim to measure memory pressure.
- Persist the preference and update the status item immediately.

## Sizing and appearance

- Measure content rather than using fixed heights per layout. Keep consistent bottom padding immediately after the footer.
- Cap total height to the available screen space at the status item. Scroll only when content exceeds that cap, including when details or Customize expand.
- Keep the header and footer accessible while longer content scrolls. Native typography, controls, materials, and adaptive colors support light and dark appearance.
- Browser mockups are illustrative; implementation uses SwiftUI/AppKit and real monitoring values.

## Validation

- Check all three layouts with Customize open/closed in light and dark mode, including compact disclosure expansion and shorter screens.
- Check all menu bar styles with usage colors enabled/disabled, boundary readings at 60/80%, and unavailable readings.
- Verify immediate changes without closing/reopening the popover, preference persistence, Command-comma, launch-at-login feedback, and retained monitoring history.

## Scope

No monitoring calculations, graph palette, token tracking, or release changes. Figma synchronization is deferred until after release. Prompt the user before updating it with all recent changes.

Status: approved and implemented locally on 2026-11-07; validated in light/dark appearance, native controls, tests, and Debug/Release builds. Not released.
