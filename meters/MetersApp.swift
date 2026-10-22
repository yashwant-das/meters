//
//  MetersApp.swift
//  meters
//
//  Created by Yashwant Das on 12/10/26.
//

import SwiftUI
import AppKit
import Charts
import Combine
import IOKit
import ServiceManagement

// MARK: - App entry

@main
struct MetersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows; everything lives in the menu bar.
        Settings { EmptyView() }
    }
}

// MARK: - Preferences

enum Prefs {
    /// When true, the menu bar shows icons instead of "CPU", "RAM" and "GPU".
    static let iconLabelsKey = "useIconLabels"
}

// MARK: - Monitor (samples CPU / RAM / GPU)

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var ram: Double = 0
    @Published private(set) var gpu: Double? = nil
    @Published private(set) var ramUsedGB: Double = 0
    @Published private(set) var ramTotalGB: Double = 0

    @Published private(set) var cpuHistory = [Double](repeating: 0, count: 60)
    @Published private(set) var ramHistory = [Double](repeating: 0, count: 60)
    @Published private(set) var gpuHistory = [Double](repeating: 0, count: 60)

    /// Called after every sample so the menu bar title can refresh.
    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var previousTicks: (UInt32, UInt32, UInt32, UInt32)?

    init(interval: TimeInterval = 2) {
        ramTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        _ = readCPU() // prime the delta
        sample()

        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor in monitor.sample() }
        }
        RunLoop.main.add(t, forMode: .common) // keeps ticking while menus/popovers are open
        timer = t
    }

    private func sample() {
        cpu = readCPU()
        let mem = readMemory()
        ram = mem.percent
        ramUsedGB = mem.usedGB
        gpu = readGPU()

        cpuHistory = Array((cpuHistory + [cpu]).suffix(60))
        ramHistory = Array((ramHistory + [ram]).suffix(60))
        gpuHistory = Array((gpuHistory + [gpu ?? 0]).suffix(60))
        onUpdate?()
    }

    // MARK: CPU (aggregate ticks, diffed between samples)

    private func readCPU() -> Double {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info_data_t()

        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        let now = (info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3) // user, system, idle, nice
        defer { previousTicks = now }
        guard let prev = previousTicks else { return 0 }

        let user = Double(now.0 &- prev.0)
        let system = Double(now.1 &- prev.1)
        let idle = Double(now.2 &- prev.2)
        let nice = Double(now.3 &- prev.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(100, max(0, (total - idle) / total * 100))
    }

    // MARK: Memory (matches Activity Monitor's "Memory Used": app + wired + compressed)

    private func readMemory() -> (percent: Double, usedGB: Double) {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()

        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0) }

        let pageSize = Double(getpagesize())
        let pages = Double(stats.internal_page_count)
            - Double(stats.purgeable_count)
            + Double(stats.wire_count)
            + Double(stats.compressor_page_count)
        let usedBytes = pages * pageSize
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        return (min(100, usedBytes / totalBytes * 100), usedBytes / 1_073_741_824)
    }

    // MARK: GPU (undocumented IOKit stats; returns nil if unavailable)

    private func readGPU() -> Double? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(0, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var best: Double?
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = unmanaged?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                let keys = ["Device Utilization %", "GPU Activity(%)", "Renderer Utilization %"]
                for key in keys {
                    if let v = (perf[key] as? NSNumber)?.doubleValue {
                        best = max(best ?? 0, v)
                        break
                    }
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return best.map { min(100, max(0, $0)) }
    }
}

// MARK: - App delegate (status item + popover)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let monitor = SystemMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatsView(monitor: monitor))

        monitor.onUpdate = { [weak self] in self?.renderTitle() }
        // Redraw straight away when the label style is switched in the popover.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.renderTitle() }
        }
        renderTitle()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Builds `CPU 12% | RAM 48% | GPU 8%` (or the icon version) with native menu bar typography.
    private func renderTitle() {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .baselineOffset: 0.5
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let useIcons = UserDefaults.standard.bool(forKey: Prefs.iconLabelsKey)

        let title = NSMutableAttributedString()
        func add(_ name: String, _ symbol: String, _ value: Double?) {
            if title.length > 0 {
                title.append(NSAttributedString(string: "  |  ", attributes: sepAttrs))
            }
            if useIcons, let icon = labelIcon(symbol, name) {
                title.append(icon)
                title.append(NSAttributedString(string: " ", attributes: labelAttrs))
            } else {
                title.append(NSAttributedString(string: name + " ", attributes: labelAttrs))
            }
            var attrs = valueAttrs
            // Keep low or unavailable usage neutral; highlight elevated percentages.
            let color: NSColor
            if let value, value >= 80 {
                color = .systemRed
            } else if let value, value >= 60 {
                color = .systemOrange
            } else {
                color = .labelColor
            }
            attrs[.foregroundColor] = color
            title.append(NSAttributedString(string: format(value), attributes: attrs))
        }

        // Same SF Symbols as the popover rows.
        add("CPU", "cpu", monitor.cpu)
        add("RAM", "memorychip", monitor.ram)
        add("GPU", "display", monitor.gpu)
        statusItem.button?.attributedTitle = title
    }

    /// An SF Symbol sized and coloured like the text labels, as an inline attachment.
    private func labelIcon(_ symbol: String, _ description: String) -> NSAttributedString? {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(config) else { return nil }

        let attachment = NSTextAttachment()
        attachment.image = image
        // Nudge down so the icon sits on the same line as the digits.
        attachment.bounds = CGRect(x: 0, y: -2, width: image.size.width, height: image.size.height)
        return NSAttributedString(attachment: attachment)
    }

    /// Pads with figure spaces (same width as digits) so the bar doesn't jitter.
    private func format(_ value: Double?) -> String {
        guard let value else { return "--%" }
        let number = String(Int(value.rounded()))
        let pad = String(repeating: "\u{2007}", count: max(0, 2 - number.count))
        return pad + number + "%"
    }
}

// MARK: - Popover UI

struct StatsView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(Prefs.iconLabelsKey) private var useIconLabels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricRow(title: "CPU", symbol: "cpu", value: monitor.cpu,
                      detail: nil, history: monitor.cpuHistory, tint: .blue)

            MetricRow(title: "RAM", symbol: "memorychip", value: monitor.ram,
                      detail: String(format: "%.1f of %.0f GB", monitor.ramUsedGB, monitor.ramTotalGB),
                      history: monitor.ramHistory, tint: .green)

            MetricRow(title: "GPU", symbol: "display", value: monitor.gpu,
                      detail: nil, history: monitor.gpuHistory, tint: .orange)

            Divider()

            HStack {
                Text("Icons in menu bar")
                Spacer()
                Toggle("Icons in menu bar", isOn: $useIconLabels)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            HStack {
                Text("Launch at login")
                Spacer()
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            NSSound.beep()
                        }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Divider()

            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Text("Quit Meters")
                    Spacer()
                    Text("⌘Q")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 280)
    }
}

struct MetricRow: View {
    let title: String
    let symbol: String
    let value: Double?
    let detail: String?
    let history: [Double]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(value.map { "\(Int($0.rounded()))%" } ?? "N/A")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, v in
                    AreaMark(x: .value("t", index), y: .value("v", v))
                        .foregroundStyle(
                            LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("t", index), y: .value("v", v))
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 38)
        }
    }
}
