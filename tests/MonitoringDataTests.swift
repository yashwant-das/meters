import Foundation

@main
struct MonitoringDataTests {
    static func main() {
        var timeline = HistoryTimeline()
        for i in 0..<60 { timeline.record(at: Double(i * 2)) }
        assert(timeline.timestamps.count == 60 && timeline.duration == 118)
        timeline.record(at: 130)
        assert(timeline.timestamps.first == 10 && timeline.timestamps.last == 130)
        assert(timeline.duration == 120 && timeline.offsets.last == 120)
        timeline.record(at: 300)
        assert(timeline.timestamps == [300] && timeline.duration == 0)
        assert(timeline.offsets == [0])
        var irregular = HistoryTimeline()
        for time in [10.0, 13.0, 20.0] { irregular.record(at: time) }
        assert(irregular.offsets == [0, 3, 10] && irregular.duration == 10)

        // Catches using lifetime ticks instead of deltas, and mis-grouping cores.
        let previous: [UInt32] = [10, 10, 80, 0, 20, 10, 70, 0]
        let current: [UInt32] = [20, 20, 160, 0, 60, 20, 120, 0]
        let usage = CPUUsage(current: current, previous: previous, efficiencyIDs: [0], performanceIDs: [1])
        assert(usage.total == 35)
        assert(usage.efficiency == 20)
        assert(usage.performance == 50)
        let unavailable = CPUUsage(current: current, previous: [], efficiencyIDs: [], performanceIDs: [])
        assert(unavailable.total == nil && unavailable.efficiency == nil)
        let idle = CPUUsage(current: current, previous: current, efficiencyIDs: [0], performanceIDs: [1])
        assert(idle.total == 0)
        let wrapped = CPUUsage(current: [5, 0, 10, 0], previous: [UInt32.max - 4, 0, 0, 0], efficiencyIDs: [0], performanceIDs: [])
        assert(wrapped.total == 50)

        // Catches double counting compressed pages and treating purgeable memory as used.
        let memory = MemoryBreakdown(internalPages: 100, purgeablePages: 20, wiredPages: 30,
                                     compressedPages: 10, pageSize: 1024, totalBytes: 204800)
        assert(memory.activeBytes == 81920)
        assert(memory.usedBytes == 122880)
        assert(memory.freeBytes == 81920)
        assert(memory.percent == 60)
        let empty = MemoryBreakdown(internalPages: 0, purgeablePages: 10, wiredPages: 0,
                                    compressedPages: 0, pageSize: 4096, totalBytes: 0)
        assert(empty.activeBytes == 0 && empty.percent == 0)

        // Catches conflating allocated GPU memory with memory actually in use.
        let gpu = GPUReading(statistics: ["Device Utilization %": 150, "In use system memory": 1024,
                                          "Alloc system memory": 4096])
        assert(gpu.utilization == 100 && gpu.memoryBytes == 1024)
        let fallback = GPUReading(statistics: ["GPU Activity(%)": 12])
        assert(fallback.utilization == 12 && fallback.memoryBytes == nil)
        let missing = GPUReading(statistics: ["In use system memory": -1])
        assert(missing.utilization == nil && missing.memoryBytes == nil)
        print("Monitoring data tests passed")
    }
}
