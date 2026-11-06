import Foundation

/// Keep a real two-minute window even when timers are delayed or the Mac sleeps.
struct HistoryTimeline {
    private(set) var timestamps: [TimeInterval] = []

    mutating func record(at time: TimeInterval) {
        timestamps = Array((timestamps + [time]).suffix(60)).filter { time - $0 <= 120 }
    }

    var offsets: [TimeInterval] {
        guard let first = timestamps.first else { return [] }
        return timestamps.map { $0 - first }
    }

    var duration: Int {
        guard let first = timestamps.first, let last = timestamps.last else { return 0 }
        return Int(max(0, last - first))
    }
}

/// Mach reports four counters per logical CPU: user, system, idle, nice.
struct CPUUsage {
    let total: Double?
    let efficiency: Double?
    let performance: Double?

    init(current: [UInt32], previous: [UInt32], efficiencyIDs: [Int], performanceIDs: [Int]) {
        guard !current.isEmpty, current.count == previous.count, current.count.isMultiple(of: 4) else {
            total = nil; efficiency = nil; performance = nil
            return
        }
        let count = current.count / 4
        func usage(_ ids: [Int]) -> Double? {
            guard !ids.isEmpty, ids.allSatisfy({ (0..<count).contains($0) }) else { return nil }
            var busy = 0.0
            var ticks = 0.0
            for id in ids {
                for state in 0..<4 {
                    let delta = Double(current[id * 4 + state] &- previous[id * 4 + state])
                    ticks += delta
                    if state != 2 { busy += delta }
                }
            }
            return ticks > 0 ? min(100, max(0, busy / ticks * 100)) : 0
        }
        total = usage(Array(0..<count))
        efficiency = usage(efficiencyIDs)
        performance = usage(performanceIDs)
    }
}

struct MemoryBreakdown {
    let activeBytes: Double
    let wiredBytes: Double
    let compressedBytes: Double
    let totalBytes: Double
    var usedBytes: Double { activeBytes + wiredBytes + compressedBytes }
    // Includes reclaimable cache, consistent with the existing Memory Used calculation.
    var freeBytes: Double { max(0, totalBytes - usedBytes) }
    var percent: Double { totalBytes > 0 ? min(100, usedBytes / totalBytes * 100) : 0 }

    init(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64,
         compressedPages: UInt64, pageSize: Double, totalBytes: Double) {
        activeBytes = max(0, Double(internalPages) - Double(purgeablePages)) * pageSize
        wiredBytes = Double(wiredPages) * pageSize
        compressedBytes = Double(compressedPages) * pageSize
        self.totalBytes = totalBytes
    }
}

struct GPUReading {
    let utilization: Double?
    let memoryBytes: Double?

    init(statistics: [String: Any]) {
        utilization = ["Device Utilization %", "GPU Activity(%)", "Renderer Utilization %"]
            .compactMap { (statistics[$0] as? NSNumber)?.doubleValue }
            .first(where: { $0.isFinite && $0 >= 0 }).map { min(100, $0) }
        memoryBytes = ((statistics["In use system memory"] as? NSNumber)?.doubleValue)
            .flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}
