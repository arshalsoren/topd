import Foundation

public enum ProcessSort: String, CaseIterable, Sendable {
    case cpu, memory, name, pid

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .name: return "Name"
        case .pid: return "PID"
        }
    }
}

public enum ProcessRanking {
    public static let topCount = 5

    /// Case-insensitive match on name, or on PID digits. An empty query keeps everything.
    public static func filter(_ rows: [ProcessRow], query: String) -> [ProcessRow] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return rows }
        return rows.filter { $0.name.lowercased().contains(needle) || String($0.pid).contains(needle) }
    }

    /// Ordering for display. Numeric keys sort descending; ties break on the lower PID so rows do not jump.
    public static func sorted(_ rows: [ProcessRow], by sort: ProcessSort) -> [ProcessRow] {
        switch sort {
        case .cpu: return rows.sorted { ($0.cpuPercent, -$0.pid) > ($1.cpuPercent, -$1.pid) }
        case .memory: return rows.sorted { ($0.memoryBytes, -$0.pid) > ($1.memoryBytes, -$1.pid) }
        case .name: return rows.sorted { ($0.name.lowercased(), $0.pid) < ($1.name.lowercased(), $1.pid) }
        case .pid: return rows.sorted { $0.pid < $1.pid }
        }
    }

    /// Selection: the top `count` processes by CPU. Display order is applied separately with `sorted`.
    public static func topByCPU(_ rows: [ProcessRow], count: Int = topCount) -> [ProcessRow] {
        Array(sorted(rows, by: .cpu).prefix(count))
    }

    public static func topByMemory(_ rows: [ProcessRow], count: Int = topCount) -> [ProcessRow] {
        Array(sorted(rows, by: .memory).prefix(count))
    }
}
