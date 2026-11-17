import Foundation

/// Memory split the way Activity Monitor frames it: app memory, wired, compressed, and free.
public struct MemoryUsage: Equatable, Sendable {
    public var total: UInt64 = 0
    public var app: UInt64 = 0
    public var wired: UInt64 = 0
    public var compressed: UInt64 = 0
    public var free: UInt64 = 0

    public init() {}

    public var used: UInt64 { app + wired + compressed }
    public var fraction: Double { total == 0 ? 0 : Double(used) / Double(total) }
}

public struct StorageUsage: Equatable, Sendable {
    public var total: UInt64 = 0
    public var available: UInt64 = 0

    public init() {}

    public var used: UInt64 { total > available ? total - available : 0 }
    public var fraction: Double { total == 0 ? 0 : Double(used) / Double(total) }
}

public struct NetworkRate: Equatable, Sendable {
    public var downloadBytesPerSecond: Double = 0
    public var uploadBytesPerSecond: Double = 0

    public init() {}
}

public struct SystemSnapshot: Equatable, Sendable {
    public var cpuTotal: Double = 0
    public var cpuPerCore: [Double] = []
    public var memory = MemoryUsage()
    /// nil when the GPU counter is not exposed on this Mac.
    public var gpuPercent: Double?
    public var gpuName: String = ""
    public var storage = StorageUsage()
    public var network = NetworkRate()
    public var uptime: TimeInterval = 0
    public var loadAverage: [Double] = []
    public var coreCount: Int = 0

    public init() {}
}

public struct ProcessRow: Identifiable, Equatable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    /// Percent of one core, so one process can exceed 100 on multi-core machines (Activity Monitor convention).
    public let cpuPercent: Double
    public let memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}
