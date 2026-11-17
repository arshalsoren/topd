import AppKit
import SwiftUI
import TopdCore

/// The validated categorical palette from the dataviz reference (`references/palette.md`).
/// Slot numbers keep their hue; each card owns one slot, so a metric keeps its color everywhere.
enum Palette {
    private static let light: [UInt32] = [0x2a78d6, 0xeb6834, 0x1baf7a, 0xeda100, 0xe87ba4, 0x008300, 0x6250d6, 0xe34948]
    private static let dark: [UInt32] = [0x3987e5, 0xd95926, 0x199e70, 0xc98500, 0xd55181, 0x008300, 0x9085e9, 0xe66767]

    static func slot(_ number: Int) -> Color {
        dynamic(light: light[number - 1], dark: dark[number - 1])
    }

    static let gridline = dynamic(light: 0xe1e0d9, dark: 0x2c2c2a)

    // Status colors are reserved and always shipped with an icon and a label, never color alone.
    static let serious = dynamic(light: 0xec835a, dark: 0xec835a)
    static let critical = dynamic(light: 0xd03b3b, dark: 0xd03b3b)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

extension Card {
    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "display"
        case .storage: return "internaldrive"
        case .system: return "server.rack"
        case .network: return "network"
        }
    }

    /// Fixed per card. Network uses slot 2 for download and slot 7 for upload.
    var slot: Int {
        switch self {
        case .cpu: return 1
        case .network: return 2
        case .memory: return 3
        case .storage: return 4
        case .gpu: return 5
        case .system: return 7
        }
    }

    var color: Color { Palette.slot(slot) }

    /// The compact value shown in the menu bar glance strip.
    func glanceText(_ snapshot: SystemSnapshot) -> String {
        switch self {
        case .cpu: return Format.percent(snapshot.cpuTotal, digits: 0)
        case .memory: return Format.percent(snapshot.memory.fraction * 100, digits: 0)
        case .gpu: return snapshot.gpuPercent.map { Format.percent($0, digits: 0) } ?? "–"
        case .storage: return Format.percent(snapshot.storage.fraction * 100, digits: 0)
        case .system: return String(format: "%.2f", snapshot.loadAverage.first ?? 0)
        case .network: return Format.compactRate(snapshot.network.downloadBytesPerSecond) + "↓"
        }
    }
}
