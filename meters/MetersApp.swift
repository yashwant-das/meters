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
        // Route the standard Settings command to customization in the status popover.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { appDelegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

// MARK: - Monitor (samples CPU / RAM / GPU)

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpu: Double = 0
    @Published private(set) var ram: Double = 0
    @Published private(set) var gpu: Double?
    @Published private(set) var efficiencyCPU: Double?
    @Published private(set) var performanceCPU: Double?
    @Published private(set) var memory: MemoryBreakdown?
    @Published private(set) var gpuMemoryGB: Double?
    @Published private(set) var loadAverage: [Double] = []
    @Published private(set) var uptime: TimeInterval = 0
    @Published private(set) var thermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var cpuHistory: [Double?] = []
    @Published private(set) var efficiencyHistory: [Double?] = []
    @Published private(set) var performanceHistory: [Double?] = []
    @Published private(set) var gpuHistory: [Double?] = []
    @Published private(set) var gpuMemoryHistory: [Double?] = []
    @Published private(set) var historySeconds = 0
    @Published private(set) var historyTimes: [TimeInterval] = []

    let ramTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    var ramUsedGB: Double { (memory?.usedBytes ?? 0) / 1_073_741_824 }
    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var previousTicks: [UInt32] = []
    private let coreGroups = SystemMonitor.readCoreGroups()
    private var historyTimeline = HistoryTimeline()
    private let interval: TimeInterval

    init(interval: TimeInterval = 2) {
        self.interval = interval
        _ = readCPU()
        sample()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit { timer?.invalidate() }

    private func sample() {
        let usage = readCPU()
        cpu = usage.total ?? cpu
        efficiencyCPU = usage.efficiency
        performanceCPU = usage.performance
        memory = readMemory()
        ram = memory?.percent ?? ram
        let graphics = readGPU()
        gpu = graphics?.utilization
        gpuMemoryGB = graphics?.memoryBytes.map { $0 / 1_073_741_824 }
        thermalState = ProcessInfo.processInfo.thermalState
        uptime = ProcessInfo.processInfo.systemUptime
        var loads = [Double](repeating: 0, count: 3)
        loadAverage = getloadavg(&loads, 3) == 3 ? loads : []
        historyTimeline.record(at: ProcessInfo.processInfo.systemUptime)
        func append(_ history: inout [Double?], _ value: Double?) {
            history = Array((history + [value]).suffix(historyTimeline.timestamps.count))
        }
        append(&cpuHistory, usage.total)
        append(&efficiencyHistory, efficiencyCPU)
        append(&performanceHistory, performanceCPU)
        append(&gpuHistory, gpu)
        append(&gpuMemoryHistory, graphics?.memoryBytes.map {
            $0 / Double(ProcessInfo.processInfo.physicalMemory) * 100
        })
        historyTimes = historyTimeline.offsets
        historySeconds = historyTimeline.duration
        onUpdate?()
    }

    private func readCPU() -> CPUUsage {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                         &count, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else {
            return CPUUsage(current: [], previous: [], efficiencyIDs: [], performanceIDs: [])
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        let ticks = UnsafeBufferPointer(start: info, count: Int(infoCount)).map { UInt32(bitPattern: $0) }
        defer { previousTicks = ticks }
        return CPUUsage(current: ticks, previous: previousTicks,
                        efficiencyIDs: coreGroups.efficiency, performanceIDs: coreGroups.performance)
    }

    /// Map logical IDs explicitly rather than assuming E/P ordering on every chip.
    private static func readCoreGroups() -> (efficiency: [Int], performance: [Int]) {
        let cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")
        guard cpus != 0 else { return ([], []) }
        defer { IOObjectRelease(cpus) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS else {
            return ([], [])
        }
        defer { IOObjectRelease(iterator) }
        var efficiency: [Int] = []
        var performance: [Int] = []
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            let kind = IORegistryEntryCreateCFProperty(entry, "cluster-type" as CFString,
                                                       kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data
            let id = IORegistryEntryCreateCFProperty(entry, "logical-cpu-id" as CFString,
                                                     kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
            if let id = id?.intValue, let kind {
                if kind.first == Character("E").asciiValue { efficiency.append(id) }
                if kind.first == Character("P").asciiValue { performance.append(id) }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return (efficiency, performance)
    }

    private func readMemory() -> MemoryBreakdown? {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryBreakdown(internalPages: UInt64(stats.internal_page_count),
                               purgeablePages: UInt64(stats.purgeable_count),
                               wiredPages: UInt64(stats.wire_count),
                               compressedPages: UInt64(stats.compressor_page_count),
                               pageSize: Double(getpagesize()),
                               totalBytes: Double(ProcessInfo.processInfo.physicalMemory))
    }

    private func readGPU() -> GPUReading? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        var best: GPUReading?
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = unmanaged?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                let reading = GPUReading(statistics: perf)
                // Keep usage and memory from the same device on multi-GPU Macs.
                if best == nil || (reading.utilization ?? -1) > (best?.utilization ?? -1) {
                    best = reading
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return best
    }
}

// MARK: - App delegate (status item, popover, settings)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let monitor = SystemMonitor()
    private let presentation = PopoverPresentation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        #endif
        Prefs.migrate()
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: StatsView(monitor: monitor, presentation: presentation) { [weak self] size in
            // Apply after SwiftUI finishes its measurement pass.
            DispatchQueue.main.async { [weak self] in
                guard let self, abs(self.popover.contentSize.height - size.height) > 0.5 else { return }
                self.popover.contentSize = size
            }
        })
        monitor.onUpdate = { [weak self] in self?.renderTitle() }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.preferencesChanged() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAvailableHeight() }
        }
        preferencesChanged()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown { popover.performClose(sender) }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        updateAvailableHeight()
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateAvailableHeight() {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        // Leave room for the arrow and a small margin above the Dock.
        presentation.maximumHeight = max(1, (screen?.visibleFrame.height ?? 800) - 24)
    }

    private func preferencesChanged() { renderTitle() }

    func popoverDidClose(_ notification: Notification) { presentation.reset() }

    private func renderTitle() {
        let style = MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: Prefs.menuBarStyleKey) ?? "") ?? .text
        guard let button = statusItem.button else { return }
        button.attributedTitle = MenuBarRenderer.title(cpu: monitor.cpu, ram: monitor.ram, gpu: monitor.gpu, style: style,
                                                     usageColors: UserDefaults.standard.bool(forKey: Prefs.usageColorsKey))
        button.setAccessibilityLabel("Meters")
        button.setAccessibilityValue("CPU \(MenuBarPresentation.percent(monitor.cpu)), GPU \(MenuBarPresentation.percent(monitor.gpu)), memory \(MenuBarPresentation.percent(monitor.ram))")
        button.toolTip = "Meters — CPU, GPU and memory usage"
    }

    func showSettings() {
        presentation.openCustomization()
        showPopover()
    }
}
