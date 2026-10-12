# Meters

A tiny macOS menu bar app that shows your Mac's CPU, memory and GPU usage at a glance.

```
CPU 12%  |  RAM 48%  |  GPU 8%
```

Click it for a native popover with live graphs. No Dock icon, no windows, almost no CPU cost.

## Features

- Live CPU, memory and GPU usage in the menu bar
- Native look: system fonts, SF Symbols, light and dark mode
- Popover with a 2-minute history graph for each metric
- Launch at login
- One Swift file, no dependencies

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later to build

## Build from source

1. Clone the repo and open `meters.xcodeproj` in Xcode.
2. In Signing & Capabilities, select your team (or "Sign to Run Locally").
3. Make sure **App Sandbox is off**. The GPU numbers come from IOKit, which the sandbox can block.
4. Press Run (⌘R).

## How it works

| Metric | Source |
|---|---|
| CPU | `host_statistics` tick counts, compared between samples |
| Memory | `host_statistics64`, counting app + wired + compressed memory (the same idea as Activity Monitor's "Memory Used") |
| GPU | IOKit `IOAccelerator` `PerformanceStatistics` |

The GPU values come from an undocumented IOKit interface. Key names differ between hardware and macOS versions, so on some machines the GPU may show `--%`. If that happens on yours, please open an issue with your Mac model and macOS version.

## Contributing

Issues and pull requests are welcome. Ideas that would be nice to have:

- Per-core CPU view
- Network and disk activity
- Choose which metrics appear in the menu bar
- Custom refresh interval

## License

[MIT](LICENSE)
