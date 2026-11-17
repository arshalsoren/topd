import SwiftUI
import TopdCore

/// Glass card chrome shared by all six metric cards: icon, title, hero value, caption, then the chart.
struct CardShell<Content: View>: View {
    let card: Card
    let headline: String
    let caption: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: card.symbol)
                    .foregroundStyle(card.color)
                Text(card.title)
                    .font(.caption.weight(.semibold))
                    .themedSecondary()
                Spacer()
            }
            Text(headline)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text(caption)
                .font(.caption)
                .themedSecondary()
                .lineLimit(1)
            content
                .padding(.top, 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title), \(headline), \(caption)")
    }
}

struct CardView: View {
    let card: Card
    let monitor: Monitor

    var body: some View {
        let s = monitor.snapshot
        switch card {
        case .cpu:
            CardShell(card: card, headline: Format.percent(s.cpuTotal), caption: "\(s.coreCount) cores · average") {
                VStack(alignment: .leading, spacing: 4) {
                    TimeSeriesChart(series: [.init(name: "CPU", color: card.color, values: monitor.cpuHistory.values)], domain: 0...100)
                    CoreBars(values: s.cpuPerCore, color: card.color)
                }
            }

        case .memory:
            CardShell(
                card: card,
                headline: Format.bytes(s.memory.used),
                caption: "of \(Format.bytes(s.memory.total)) · \(Format.percent(s.memory.fraction * 100))"
            ) {
                MemoryBreakdownChart(usage: s.memory, color: card.color)
            }

        case .gpu:
            CardShell(
                card: card,
                headline: s.gpuPercent.map { Format.percent($0) } ?? "–",
                caption: s.gpuPercent == nil ? "Not reported on this Mac" : s.gpuName
            ) {
                TimeSeriesChart(series: [.init(name: "GPU", color: card.color, values: monitor.gpuHistory.values)], domain: 0...100)
            }

        case .storage:
            let status = StorageStatus(fraction: s.storage.fraction)
            CardShell(
                card: card,
                headline: Format.bytes(s.storage.available, style: .file),
                caption: "free of \(Format.bytes(s.storage.total, style: .file))"
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    MeterBar(fraction: s.storage.fraction, color: card.color)
                    HStack {
                        Text("\(Format.percent(s.storage.fraction * 100)) used")
                            .font(.caption)
                            .themedSecondary()
                        Spacer()
                        if let status {
                            Label(status.text, systemImage: status.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(status.color)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }

        case .system:
            CardShell(card: card, headline: Format.uptime(s.uptime), caption: "uptime · load average") {
                LoadBars(loads: s.loadAverage, cores: s.coreCount, color: card.color)
            }

        case .network:
            CardShell(
                card: card,
                headline: "↓ " + Format.rate(s.network.downloadBytesPerSecond),
                caption: "↑ " + Format.rate(s.network.uploadBytesPerSecond)
            ) {
                TimeSeriesChart(
                    series: [
                        .init(name: "Download", color: card.color, values: monitor.downloadHistory.values),
                        .init(name: "Upload", color: Palette.slot(7), values: monitor.uploadHistory.values),
                    ],
                    format: { Format.rate($0) },
                    axisFormat: { Format.compactRate($0) }
                )
            }
        }
    }
}

/// Storage severity. Always shown with an icon and text, never color alone.
private struct StorageStatus {
    let text: String
    let symbol: String
    let color: Color

    init?(fraction: Double) {
        switch fraction {
        case 0.95...:
            text = "Almost full"
            symbol = "exclamationmark.octagon.fill"
            color = Palette.critical
        case 0.85...:
            text = "Filling up"
            symbol = "exclamationmark.triangle.fill"
            color = Palette.serious
        default:
            return nil
        }
    }
}
