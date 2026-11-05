import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var monitor: SystemMonitor
    var openSettings: () -> Void
    @AppStorage(Prefs.popoverLayoutKey) private var layout: PopoverLayout = .grouped
    @State private var memoryExpanded = false
    @State private var systemExpanded = false

    static func height(for layout: PopoverLayout) -> CGFloat {
        let preferred: CGFloat = layout == .compact ? 490 : (layout == .activity ? 690 : 730)
        return min(preferred, (NSScreen.main?.visibleFrame.height ?? 850) - 80)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Meters").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 4, height: 4)
                        Text("Live").font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    .help("Updates every 2 seconds")
                }
                .padding(.bottom, 2)

                if layout == .activity { overview }
                metricSection { cpuContent }
                if layout != .grouped { Divider() }
                metricSection { gpuContent }
                if layout != .grouped { Divider() }
                metricSection { memoryContent }

                if layout == .compact {
                    Divider()
                    thermalRow
                    DisclosureGroup("System details", isExpanded: $systemExpanded) {
                        systemDetails.padding(.top, 6)
                    }
                    .font(.caption)
                    .tint(.secondary)
                } else {
                    thermalRow
                    systemDetails
                }
                footer
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .frame(width: 316, height: Self.height(for: layout))
    }

    private func metricSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(layout == .grouped ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if layout == .grouped {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                }
            }
    }

    private var cpuContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layout == .activity { chartHeading("CPU history") }
            else { MetricHeader(title: "CPU", symbol: "cpu", value: monitor.cpu) }
            if layout == .grouped { cpuLegend }
            HistoryChart(series: cpuSeries, times: monitor.historyTimes, height: chartHeight, label: "CPU usage history")
            if layout != .compact { historyAxis }
            if layout != .grouped { cpuLegend }
        }
    }

    private var gpuContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layout == .activity { chartHeading("GPU history") }
            else { MetricHeader(title: "GPU", symbol: "display", value: monitor.gpu) }
            if layout == .grouped { gpuLegend }
            HistoryChart(series: [
                .init(name: "GPU", values: monitor.gpuHistory, tint: .blue),
                .init(name: "GPU memory", values: monitor.gpuMemoryHistory, tint: .teal)
            ], times: monitor.historyTimes, height: chartHeight, label: "GPU usage and memory history")
            if layout != .compact { historyAxis }
            if layout != .grouped { gpuLegend }
        }
    }

    private var chartHeight: CGFloat { layout == .compact ? 34 : 48 }

    private var cpuSeries: [HistoryChart.Series] {
        if monitor.efficiencyCPU == nil && monitor.performanceCPU == nil {
            return [.init(name: "CPU", values: monitor.cpuHistory, tint: .blue)]
        }
        return [
            .init(name: "Efficiency", values: monitor.efficiencyHistory, tint: .orange),
            .init(name: "Performance", values: monitor.performanceHistory, tint: .blue)
        ]
    }

    private var cpuLegend: some View {
        HStack {
            if monitor.efficiencyCPU == nil && monitor.performanceCPU == nil {
                SeriesKey(title: "CPU", value: percent(monitor.cpu), tint: .blue)
                Spacer(minLength: 0)
                Text("Core split unavailable").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                SeriesKey(title: "Efficiency", value: percent(monitor.efficiencyCPU), tint: .orange)
                Spacer(minLength: 4)
                SeriesKey(title: "Performance", value: percent(monitor.performanceCPU), tint: .blue)
            }
        }
        .help("Average utilization within each core group; the CPU total is weighted across all cores")
    }

    private var gpuLegend: some View {
        HStack {
            SeriesKey(title: "GPU", value: nil, tint: .blue)
            Spacer(minLength: 4)
            SeriesKey(title: "Memory", value: monitor.gpuMemoryGB.map { String(format: "%.2f GB", $0) } ?? "N/A", tint: .teal)
        }
        .help("GPU memory overlaps system memory. Its graph shows a share of total system memory, not dedicated VRAM.")
    }

    private var historyAxis: some View {
        HStack {
            Text(monitor.historySeconds < 2 ? "Collecting history…" : historyStart)
            Spacer()
            Text("Now")
        }
        .font(.system(size: 9)).foregroundStyle(.tertiary)
    }

    private var historyStart: String {
        let seconds = monitor.historySeconds
        return seconds < 60 ? "\(seconds)s ago" : "\(seconds / 60)m \(seconds % 60)s ago"
    }

    private func chartHeading(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold))
            Spacer()
            Text("0–100%").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var overview: some View {
        HStack(spacing: 0) {
            overviewReading("CPU", value: monitor.cpu)
            Divider().frame(height: 32)
            overviewReading("GPU", value: monitor.gpu)
            Divider().frame(height: 32)
            overviewReading("Memory", value: monitor.memory?.percent)
        }
        .padding(.vertical, 10)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
    }

    private func overviewReading(_ title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(percent(value)).font(.system(size: 21, weight: .semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layout == .activity {
                DetailRow(title: "Memory", value: percent(monitor.memory?.percent))
                    .fontWeight(.semibold)
            } else { MetricHeader(title: "Memory", symbol: "memorychip", value: monitor.memory?.percent) }
            HStack {
                Text(monitor.memory == nil ? "N/A" : String(format: "%.1f GB used", monitor.ramUsedGB))
                Spacer()
                Text(String(format: "%.0f GB total", monitor.ramTotalGB))
            }
            .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
            MemoryBar(memory: monitor.memory)
                .accessibilityLabel("Memory used")
                .accessibilityValue(percent(monitor.memory?.percent))
            if layout == .compact {
                DisclosureGroup("Memory breakdown", isExpanded: $memoryExpanded) {
                    memoryDetails.padding(.top, 6)
                }
                .font(.caption).tint(.secondary)
            } else { memoryDetails }
        }
    }

    private var memoryDetails: some View {
        VStack(spacing: 6) {
            memoryRow("Wired", bytes: monitor.memory?.wiredBytes, tint: .blue)
            memoryRow("Active", bytes: monitor.memory?.activeBytes, tint: .green)
            memoryRow("Compressed", bytes: monitor.memory?.compressedBytes, tint: .purple)
            memoryRow("Available", bytes: monitor.memory?.freeBytes, tint: .gray)
                .help("Includes reclaimable cache; this is not just the kernel’s free-page count")
        }
    }

    private func memoryRow(_ title: String, bytes: Double?, tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(tint.opacity(0.8)).frame(width: 4, height: 4)
            DetailRow(title: title, value: bytes.map { String(format: "%.1f GB", $0 / 1_073_741_824) } ?? "N/A")
        }
    }

    private var thermalRow: some View {
        HStack {
            Text("Thermal state").foregroundStyle(.secondary)
            Spacer()
            Text(thermalDescription).fontWeight(.medium)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .foregroundStyle(thermalTint)
                .background(thermalTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
    }

    private var systemDetails: some View {
        VStack(spacing: 8) {
            DetailRow(title: "Load · 1 / 5 / 15 min", value: monitor.loadAverage.isEmpty ? "N/A" :
                        monitor.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " · "))
                .help("Average runnable tasks over 1, 5 and 15 minutes")
            DetailRow(title: "Uptime", value: uptimeDescription)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            HStack {
                Button(action: openSettings) { Label("Settings…", systemImage: "gearshape") }
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    HStack(spacing: 8) { Text("Quit"); Text("⌘Q").foregroundStyle(.tertiary) }
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func percent(_ value: Double?) -> String {
        guard let fraction = MenuBarPresentation.fraction(value) else { return "N/A" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    private var thermalDescription: String {
        switch monitor.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private var thermalTint: Color {
        switch monitor.thermalState {
        case .nominal: return .green
        case .fair: return .orange
        case .serious, .critical: return .red
        @unknown default: return .secondary
        }
    }

    private var uptimeDescription: String {
        let minutes = Int(monitor.uptime) / 60
        let days = minutes / 1440
        let hours = (minutes / 60) % 24
        return (days > 0 ? "\(days)d " : "") + "\(hours)h \(minutes % 60)m"
    }
}

private struct MetricHeader: View {
    let title: String
    let symbol: String
    let value: Double?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 16)
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(MenuBarPresentation.fraction(value).map { "\(Int(($0 * 100).rounded()))%" } ?? "N/A")
                .font(.system(size: 22, weight: .semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SeriesKey: View {
    let title: String
    let value: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(tint).frame(width: 4, height: 4)
            Text(value.map { "\(title) \($0)" } ?? title).monospacedDigit()
        }
        .font(.system(size: 9)).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 11))
        .accessibilityElement(children: .combine)
    }
}

private struct MemoryBar: View {
    let memory: MemoryBreakdown?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.07))
                if let memory, memory.totalBytes > 0 {
                    HStack(spacing: 0) {
                        Rectangle().fill(.blue).frame(width: width(memory.wiredBytes, in: geometry))
                        Rectangle().fill(.green.opacity(0.8)).frame(width: width(memory.activeBytes, in: geometry))
                        Rectangle().fill(.purple).frame(width: width(memory.compressedBytes, in: geometry))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
    }

    private func width(_ bytes: Double, in geometry: GeometryProxy) -> CGFloat {
        geometry.size.width * min(1, max(0, bytes / (memory?.totalBytes ?? 1)))
    }
}

private struct HistoryChart: View {
    struct Series {
        let name: String
        let values: [Double?]
        let tint: Color
    }
    let series: [Series]
    let times: [TimeInterval]
    let height: CGFloat
    let label: String

    var body: some View {
        Chart {
            ForEach(series, id: \.name) { item in
                ForEach(Array(item.values.enumerated()), id: \.offset) { index, value in
                    if let value {
                        let time = times.indices.contains(index) ? times[index] : Double(index) * 2
                        let run = item.values[..<index].lastIndex(where: { $0 == nil }) ?? -1
                        let seriesID = "\(item.name)-\(run)"
                        AreaMark(x: .value("Time", time), y: .value("Usage", value),
                                 series: .value("Metric", seriesID), stacking: .unstacked)
                            .foregroundStyle(LinearGradient(colors: [item.tint.opacity(0.10), item.tint.opacity(0.01)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Time", time), y: .value("Usage", value),
                                 series: .value("Metric", seriesID))
                            .foregroundStyle(item.tint)
                            .lineStyle(StrokeStyle(lineWidth: 1.4))
                            .interpolationMethod(.monotone)
                        if item.values.count == 1 {
                            PointMark(x: .value("Time", time), y: .value("Usage", value))
                                .foregroundStyle(item.tint).symbolSize(8)
                        }
                    }
                }
            }
        }
        .chartXScale(domain: 0...max(1, times.last ?? 0))
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.primary.opacity(0.07))
            }
        }
        .frame(height: height)
        .accessibilityLabel(label)
    }
}
