import Foundation
import IOKit
import Darwin

/// Samples whole-machine metrics. Rates and CPU percentages are deltas between consecutive calls,
/// so the first call reports zero rates.
public final class SystemSampler {
    private var previousTicks: [[UInt32]] = []
    private var previousInterfaces: [String: (received: UInt32, sent: UInt32)] = [:]
    private var previousNetworkTime: UInt64?
    /// Accelerator services are found once and kept; only their utilization is read each tick.
    private lazy var gpuServices: [io_object_t] = Self.findAccelerators()
    /// Volume capacity changes slowly, so it is re-read at most every `storageInterval`.
    private var storageCache: (time: UInt64, value: StorageUsage)?
    private static let storageInterval: UInt64 = 30_000_000_000
    private let gpuName = SystemSampler.readCPUBrand()

    public init() {}

    public func sample(now: UInt64 = DispatchTime.now().uptimeNanoseconds) -> SystemSnapshot {
        let ticks = Self.readCPUTicks()
        let perCore = Self.utilization(previous: previousTicks, current: ticks)
        previousTicks = ticks

        var snapshot = SystemSnapshot()
        snapshot.cpuPerCore = perCore
        snapshot.cpuTotal = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
        snapshot.memory = Self.readMemory()
        snapshot.gpuPercent = gpuUtilization()
        snapshot.gpuName = gpuName
        if let cache = storageCache, now &- cache.time < Self.storageInterval {
            snapshot.storage = cache.value
        } else {
            let fresh = Self.readStorage()
            storageCache = (now, fresh)
            snapshot.storage = fresh
        }
        snapshot.network = networkRate(now: now)
        snapshot.uptime = ProcessInfo.processInfo.systemUptime
        snapshot.loadAverage = Self.loadAverage()
        snapshot.coreCount = ProcessInfo.processInfo.activeProcessorCount
        return snapshot
    }

    // MARK: - CPU

    /// Each inner array is one core's cumulative ticks in CPU_STATE order: user, system, idle, nice.
    /// Returns busy percent per core for the interval between the two readings.
    public static func utilization(previous: [[UInt32]], current: [[UInt32]]) -> [Double] {
        guard previous.count == current.count else { return current.map { _ in 0 } }
        return zip(previous, current).map { before, now in
            let busy = (now[0] &- before[0]) &+ (now[1] &- before[1]) &+ (now[3] &- before[3])
            let idle = now[2] &- before[2]
            let total = busy &+ idle
            return total == 0 ? 0 : Double(busy) / Double(total) * 100
        }
    }

    static func readCPUTicks() -> [[UInt32]] {
        var coreCount: natural_t = 0
        var info: processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &coreCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, UInt(bitPattern: info), size)
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(coreCount)).map { core in
            (0..<stride).map { UInt32(bitPattern: info[core * stride + $0]) }
        }
    }

    // MARK: - Memory and storage

    static func readMemory() -> MemoryUsage {
        var usage = MemoryUsage()
        usage.total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return usage }

        let page = UInt64(vm_page_size)
        let anonymous = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        usage.app = (anonymous > purgeable ? anonymous - purgeable : 0) * page
        usage.wired = UInt64(stats.wire_count) * page
        usage.compressed = UInt64(stats.compressor_page_count) * page
        usage.free = UInt64(stats.free_count) * page
        return usage
    }

    static func readStorage() -> StorageUsage {
        var storage = StorageUsage()
        let values = try? URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        )
        storage.total = UInt64(max(0, values?.volumeTotalCapacity ?? 0))
        storage.available = UInt64(max(0, values?.volumeAvailableCapacityForImportantUsage ?? 0))
        return storage
    }

    // MARK: - Network

    private func networkRate(now: UInt64) -> NetworkRate {
        let interfaces = Self.interfaceCounters()
        defer {
            previousInterfaces = interfaces
            previousNetworkTime = now
        }
        guard let last = previousNetworkTime, now > last else { return NetworkRate() }

        let seconds = Double(now - last) / 1_000_000_000
        var received = 0.0
        var sent = 0.0
        for (name, counters) in interfaces {
            guard let before = previousInterfaces[name] else { continue }
            received += Self.counterDelta(counters.received, before.received)
            sent += Self.counterDelta(counters.sent, before.sent)
        }
        var rate = NetworkRate()
        rate.downloadBytesPerSecond = received / seconds
        rate.uploadBytesPerSecond = sent / seconds
        return rate
    }

    /// 32-bit interface counters wrap; a huge apparent jump means the counter reset, so count it as zero.
    public static func counterDelta(_ current: UInt32, _ previous: UInt32) -> Double {
        let delta = current &- previous
        return delta < 0x8000_0000 ? Double(delta) : 0
    }

    static func interfaceCounters() -> [String: (received: UInt32, sent: UInt32)] {
        var result: [String: (received: UInt32, sent: UInt32)] = [:]
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return result }
        defer { freeifaddrs(first) }

        var node: UnsafeMutablePointer<ifaddrs>? = first
        while let current = node {
            let entry = current.pointee
            if let address = entry.ifa_addr,
               Int32(address.pointee.sa_family) == AF_LINK,
               entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
               let data = entry.ifa_data {
                let counters = data.assumingMemoryBound(to: if_data.self).pointee
                result[String(cString: entry.ifa_name)] = (counters.ifi_ibytes, counters.ifi_obytes)
            }
            node = entry.ifa_next
        }
        return result
    }

    // MARK: - GPU, system, identity

    /// Average "Device Utilization %" across accelerators. Read-only; needs no privileges.
    private func gpuUtilization() -> Double? {
        var readings: [Double] = []
        for service in gpuServices {
            guard let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any],
                  let utilization = stats["Device Utilization %"] as? NSNumber else { continue }
            readings.append(utilization.doubleValue)
        }
        guard !readings.isEmpty else { return nil }
        return readings.reduce(0, +) / Double(readings.count)
    }

    /// Looked up once. Services are kept for the life of the sampler.
    private static func findAccelerators() -> [io_object_t] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        var services: [io_object_t] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            services.append(service)
        }
        return services
    }

    deinit {
        gpuServices.forEach { IOObjectRelease($0) }
    }

    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)
        return loads
    }

    static func readCPUBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "Apple GPU" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "Apple GPU" }
        return String(cString: buffer)
    }
}
