import Foundation
import Darwin

/// Reads per-process CPU time and resident memory through libproc. Processes the current user
/// cannot inspect are skipped; no elevated privileges are requested.
public final class ProcessSampler {
    private var previousCPUNanos: [Int32: Double] = [:]
    private var previousTime: UInt64?
    private let timebaseNumer: Double
    private let timebaseDenom: Double

    public init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        timebaseNumer = Double(timebase.numer)
        timebaseDenom = Double(timebase.denom)
    }

    /// Drops the CPU baseline so the next sample starts fresh (used when sampling resumes after a pause).
    public func reset() {
        previousCPUNanos = [:]
        previousTime = nil
    }

    public func sample(now: UInt64 = DispatchTime.now().uptimeNanoseconds) -> [ProcessRow] {
        let elapsed = previousTime.map { Double(now - $0) } ?? 0
        var nextCPUNanos: [Int32: Double] = [:]
        var rows: [ProcessRow] = []

        for pid in Self.listPIDs() {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }

            // Task CPU time is in mach absolute-time units; convert to nanoseconds.
            let ticks = Double(info.pti_total_user + info.pti_total_system)
            let cpuNanos = ticks * timebaseNumer / timebaseDenom
            nextCPUNanos[pid] = cpuNanos

            var percent = 0.0
            if elapsed > 0, let before = previousCPUNanos[pid], cpuNanos >= before {
                percent = (cpuNanos - before) / elapsed * 100
            }
            rows.append(ProcessRow(
                pid: pid,
                name: Self.name(of: pid),
                cpuPercent: percent,
                memoryBytes: info.pti_resident_size
            ))
        }

        previousCPUNanos = nextCPUNanos
        previousTime = now
        return rows
    }

    static func listPIDs() -> [Int32] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(bytes) / MemoryLayout<Int32>.size + 32)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard filled > 0 else { return [] }
        return pids.prefix(Int(filled) / MemoryLayout<Int32>.size).filter { $0 > 0 }
    }

    static func name(of pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "pid \(pid)" }
        return String(cString: buffer)
    }
}
