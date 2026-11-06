// Documentation-only fixtures. Compile with the production views, not MetersApp.swift.
// These values illustrate the UI; they are not performance measurements.
import SwiftUI
import AppKit
import Combine

@MainActor
final class SystemMonitor: ObservableObject {
    let cpu = 24.0
    let ram = 56.25
    var gpu: Double? = 18
    var efficiencyCPU: Double? = 32
    var performanceCPU: Double? = 16
    let memory: MemoryBreakdown? = .init(internalPages: 28, purgeablePages: 0, wiredPages: 4,
                                       compressedPages: 4, pageSize: 1_073_741_824, totalBytes: 64 * 1_073_741_824)
    var gpuMemoryGB: Double? = 10
    let loadAverage = [2.4, 1.9, 1.8]
    let uptime: TimeInterval = 10_000
    let thermalState = ProcessInfo.ThermalState.nominal
    let ramTotalGB = 64.0
    var ramUsedGB: Double { (memory?.usedBytes ?? 0) / 1_073_741_824 }
    let historySeconds = 118
    let historyTimes = (0..<60).map { Double($0 * 2) }
    let cpuHistory: [Double?] = (0..<60).map { 18 + 8 * sin(Double($0) / 4) }
    let efficiencyHistory: [Double?] = (0..<60).map { 22 + 13 * sin(Double($0) / 4) }
    let performanceHistory: [Double?] = (0..<60).map { 18 + 13 * sin(Double($0) / 4 + 0.8) }
    var gpuHistory: [Double?] = (0..<60).map { 12 + 9 * sin(Double($0) / 5) }
    var gpuMemoryHistory: [Double?] = (0..<60).map { 14 + 5 * sin(Double($0) / 6) }
}

private struct StatusTitle: NSViewRepresentable {
    let style: MenuBarStyle
    var usageColors = true
    var warningSample = false
    private var title: NSAttributedString {
        MenuBarRenderer.title(cpu: warningSample ? 59 : 12, ram: warningSample ? 85 : 48,
                              gpu: warningSample ? 65 : 8, style: style, usageColors: usageColors)
    }
    func makeNSView(context: Context) -> NSTextField { NSTextField(labelWithAttributedString: title) }
    func updateNSView(_ view: NSTextField, context: Context) { view.attributedStringValue = title }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        nsView.fittingSize
    }
}

private struct MenuSamples: View {
    var colors = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if colors {
                row("Usage colors on", style: .meters, enabled: true)
                row("Usage colors off", style: .meters, enabled: false)
            } else {
                row("Text", style: .text)
                row("Symbols", style: .symbols)
                row("Micro meters", style: .meters)
            }
        }
        .padding(24)
        .frame(width: 600, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    private func row(_ name: String, style: MenuBarStyle, enabled: Bool = true) -> some View {
        HStack {
            Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 135, alignment: .leading)
            Spacer(minLength: 12)
            StatusTitle(style: style, usageColors: enabled, warningSample: colors).fixedSize()
        }
    }
}

@main
struct DocumentationCapture {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let expandedDetails = ProcessInfo.processInfo.environment["METERS_DOCS_EXPANDED"] == "1"
        var captures: [String: NSImage] = [:]
        for scheme in [ColorScheme.light, .dark] {
            let dark = scheme == .dark
            app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let suite = "Meters.DocumentationCapture.\(scheme)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }
            Prefs.migrate(in: defaults)
            for layout in PopoverLayout.allCases {
                if expandedDetails && layout != .compact { continue }
                defaults.set(layout.rawValue, forKey: Prefs.popoverLayoutKey)
                let modes = expandedDetails ? ["details"] : ["layout", "customize"]
                for mode in modes {
                    // One compact Customize view documents the shared controls for every layout.
                    if mode == "customize" && layout != .compact { continue }
                    let state = PopoverPresentation()
                    state.maximumHeight = 700
                    if mode == "customize" { state.openCustomization() }
                    let image = captureStats(state: state, defaults: defaults, scheme: scheme)
                    let name = mode == "layout" ? "\(layout.rawValue)-\(scheme)" : "\(mode)-\(scheme)"
                    captures[name] = image
                    try save(frame(image, dark: dark), to: output.appendingPathComponent(name + ".png"))
                }
            }
            if expandedDetails { continue }
            for colors in [false, true] {
                let image = capture(MenuSamples(colors: colors).environment(\.colorScheme, scheme))
                try save(frame(image, dark: dark, arrow: false),
                         to: output.appendingPathComponent("\(colors ? "usage-colors" : "menu-styles")-\(scheme).png"))
            }
            defaults.set(PopoverLayout.activity.rawValue, forKey: Prefs.popoverLayoutKey)
            let missing = SystemMonitor()
            missing.gpu = nil; missing.gpuMemoryGB = nil
            missing.efficiencyCPU = nil; missing.performanceCPU = nil
            missing.gpuHistory = Array(repeating: nil, count: 60)
            missing.gpuMemoryHistory = Array(repeating: nil, count: 60)
            let image = captureStats(state: PopoverPresentation(), defaults: defaults, scheme: scheme, monitor: missing)
            try save(frame(image, dark: dark), to: output.appendingPathComponent("unavailable-\(scheme).png"))
        }
        if !expandedDetails {
            try save(hero(light: captures["compact-light"]!, dark: captures["activity-dark"]!),
                     to: output.appendingPathComponent("hero.png"))
        }
        print("Captured documentation UI in light and dark appearance\(expandedDetails ? " (expanded details)" : "")")
    }

    @MainActor private static func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.18)) }

    @MainActor private static func captureStats(state: PopoverPresentation, defaults: UserDefaults,
                                               scheme: ColorScheme, monitor: SystemMonitor? = nil) -> NSImage {
        let window = window()
        let root = StatsView(monitor: monitor ?? SystemMonitor(), presentation: state) { size in
            DispatchQueue.main.async { window.setContentSize(size) }
        }
        .defaultAppStorage(defaults)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, scheme)
        let host = NSHostingView(rootView: root)
        window.contentView = host
        window.orderFrontRegardless()
        settle()
        let image = snapshot(host)
        window.orderOut(nil)
        return image
    }

    @MainActor private static func capture<V: View>(_ view: V) -> NSImage {
        let window = window()
        let host = NSHostingView(rootView: view)
        window.contentView = host
        window.orderFrontRegardless()
        settle()
        window.setContentSize(host.fittingSize)
        settle()
        let image = snapshot(host)
        window.orderOut(nil)
        return image
    }

    @MainActor private static func window() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 316, height: 534),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSApplication.shared.appearance
        window.isReleasedWhenClosed = false
        return window
    }

    @MainActor private static func snapshot(_ host: NSView) -> NSImage {
        host.layoutSubtreeIfNeeded(); host.display()
        let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(bitmap)
        return image
    }

    @MainActor private static func canvas(_ size: NSSize, draw: () -> Void) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2),
                                     pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // bitmap.size already establishes the 2× point-to-pixel transform.
        draw()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    @MainActor private static func panel(_ image: NSImage, rect: NSRect, dark: Bool, arrow: Bool = true) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
        if arrow {
            let mid = rect.midX
            let tip = NSBezierPath()
            tip.move(to: NSPoint(x: mid - 8, y: rect.maxY - 1))
            tip.line(to: NSPoint(x: mid, y: rect.maxY + 7))
            tip.line(to: NSPoint(x: mid + 8, y: rect.maxY - 1))
            tip.close()
            path.append(tip)
        }
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.25 : 0.13)
        shadow.shadowBlurRadius = 20
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.set()
        (dark ? NSColor(white: 0.12, alpha: 1) : .white).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13).addClip()
        image.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: dark ? 1 : 0, alpha: dark ? 0.12 : 0.08).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    @MainActor private static func frame(_ image: NSImage, dark: Bool, arrow: Bool = true) -> NSImage {
        let size = NSSize(width: image.size.width + 40, height: image.size.height + 52)
        return canvas(size) {
            (dark ? NSColor(white: 0.07, alpha: 1) : NSColor(white: 0.96, alpha: 1)).setFill()
            NSRect(origin: .zero, size: size).fill()
            panel(image, rect: NSRect(x: 20, y: 24, width: image.size.width, height: image.size.height), dark: dark, arrow: arrow)
        }
    }

    @MainActor private static func hero(light: NSImage, dark: NSImage) -> NSImage {
        let size = NSSize(width: 1100, height: 700)
        return canvas(size) {
            NSGradient(starting: NSColor(srgbRed: 0.95, green: 0.97, blue: 0.98, alpha: 1),
                       ending: NSColor(srgbRed: 0.88, green: 0.94, blue: 0.94, alpha: 1))!.draw(in: NSRect(origin: .zero, size: size), angle: -25)
            func text(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .black) {
                (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
            }
            if let icon = NSImage(contentsOfFile: "meters/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png") {
                icon.draw(in: NSRect(x: 48, y: 566, width: 64, height: 64))
            }
            text("Meters", x: 126, y: 579, size: 26, weight: .semibold, color: NSColor(white: 0.16, alpha: 1))
            text("Your Mac.", x: 52, y: 440, size: 60, weight: .bold, color: NSColor(white: 0.12, alpha: 1))
            text("At a glance.", x: 52, y: 373, size: 60, weight: .bold, color: NSColor(white: 0.12, alpha: 1))
            text("CPU, GPU and memory", x: 56, y: 314, size: 23, color: NSColor(white: 0.35, alpha: 1))
            text("at home in your menu bar.", x: 56, y: 283, size: 23, color: NSColor(white: 0.35, alpha: 1))
            text("Native macOS app · Free & open source", x: 56, y: 76, size: 14, weight: .medium, color: NSColor(white: 0.4, alpha: 1))
            let scale: CGFloat = 0.82
            panel(dark, rect: NSRect(x: 786, y: 94, width: dark.size.width * scale, height: dark.size.height * scale), dark: true)
            panel(light, rect: NSRect(x: 507, y: 164, width: light.size.width * scale, height: light.size.height * scale), dark: false)
        }
    }

    private static func save(_ image: NSImage, to url: URL) throws {
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let bitmap = NSBitmapImageRep(cgImage: cg)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
