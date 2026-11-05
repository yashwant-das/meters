# Meters appearance design

Approved direction: [Figma](https://www.figma.com/design/ZaNr6Mp1dDnydetqmW7cSN?node-id=8-4).

Keep three popover layouts (Grouped system panel, Compact menu extra, Activity Monitor miniature) and three independent menu bar styles (Refined text, Compact symbols, Text with micro meters). Settings persists each choice and applies changes immediately. Grouped/text are defaults; migrate the existing icon preference. Native system typography, popover material, controls, light/dark support, no dependencies, macOS 14+.

Approaches considered: one fixed layout, compact disclosure layout, and an overview-led layout. The user selected keeping all three, independently combined with all three status styles. Compact memory/system details expand; the other layouts display every metric. Keep CPU topology fallback, optional GPU readings, real history duration, memory breakdown, thermal/load/uptime and launch-at-login. Move preferences into a native settings window accessed from every popover. Preserve 2-second sampling and usage-color thresholds.

Menu bar values reserve three digit positions (including unavailable values) to prevent width changes. Symbols are SF Symbols, bars are tiny inline meters. GPU memory remains a share of unified system memory, not dedicated VRAM. No new metrics, network calls or tracking.

November 6 refinement: menu bar order matches the popover: CPU, GPU, RAM. Use the macOS menu bar font at its native size/weight, enabling tabular digits without switching to a monospaced typeface. The settings preview and accessibility reading order match.

Implementation choices: reuse the current checkout to preserve existing uncommitted monitoring work; keep the monitor intact; split presentation/preferences into focused files. The app uses SF Pro through the system font APIs, independent of Figma's font-rendering fallback.
