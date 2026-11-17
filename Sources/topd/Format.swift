import Foundation

enum Format {
    static func percent(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    static func bytes(_ value: UInt64, style: ByteCountFormatter.CountStyle = .memory) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: style)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }

    /// Short form for the menu bar, e.g. "512B", "1.5K", "12.0M".
    static func compactRate(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G"]
        var value = bytesPerSecond
        var index = 0
        while value >= 1000 && index < units.count - 1 {
            value /= 1000
            index += 1
        }
        return index == 0 ? "\(Int(value))B" : String(format: "%.1f%@", value, units[index])
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
