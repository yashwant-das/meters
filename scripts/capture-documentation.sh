#!/bin/bash
# Run from the repository root after building the current UI.
# Native views + isolated sample data; no changes to installed app preferences.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
task_build="${TMPDIR:-/tmp}/meters-documentation-build"
task_bundle="$task_build/MetersDocumentation.app"
task_derived="${METERS_DOCS_DERIVED_DATA:-/tmp/meters-inline-build}"
mkdir -p "$task_bundle/Contents/MacOS" "$task_bundle/Contents/Resources" docs/images
cp "$task_derived/Build/Products/Release/Meters.app/Contents/Resources/Assets.car" "$task_bundle/Contents/Resources/Assets.car"
/usr/libexec/PlistBuddy -c 'Clear dict' "$task_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string io.meters.documentation' "$task_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string capture' "$task_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$task_bundle/Contents/Info.plist"
task_sources=(meters/AppearancePreferences.swift meters/AppearanceSettingsView.swift meters/MenuBarRenderer.swift meters/MonitoringData.swift meters/PopoverPresentation.swift scripts/capture-documentation.swift)
swiftc -module-cache-path "$task_build/module-cache" "${task_sources[@]}" meters/StatsView.swift -o "$task_bundle/Contents/MacOS/capture"
"$task_bundle/Contents/MacOS/capture" "$task_root/docs/images"
# Render the same compact view with its supported disclosure states initially expanded.
# This changes only initial state in a temporary source copy, never product code/layout.
sed -e 's/@State private var memoryExpanded = false/@State private var memoryExpanded = true/' \
    -e 's/@State private var systemExpanded = false/@State private var systemExpanded = true/' \
    meters/StatsView.swift > "$task_build/ExpandedStatsView.swift"
swiftc -module-cache-path "$task_build/module-cache" "${task_sources[@]}" "$task_build/ExpandedStatsView.swift" -o "$task_bundle/Contents/MacOS/capture"
METERS_DOCS_EXPANDED=1 "$task_bundle/Contents/MacOS/capture" "$task_root/docs/images"
