import Charts
import SwiftUI
import TopdCore

/// Recent history as lines. One series adds a 12% area wash. Two or more series get a legend.
/// Hovering shows a rule and a readout; the headline value on each card is the always-visible label.
struct TimeSeriesChart: View {
    struct Series {
        let name: String
        let color: Color
        let values: [Double]
    }

    let series: [Series]
    var domain: ClosedRange<Double>?
    var format: (Double) -> String = { Format.percent($0, digits: 0) }
    var axisFormat: (Double) -> String = { String(Int($0)) }

    @StateObject private var hover = HoverState()

    private var window: Int { Monitor.historyLength - 1 }
    private var hovered: Int? { hover.index }

    var body: some View {
        Chart {
            ForEach(Array(series.enumerated()), id: \.offset) { _, line in
                ForEach(Array(line.values.enumerated()), id: \.offset) { index, value in
                    let x = index - (line.values.count - 1)
                    if series.count == 1 {
                        AreaMark(x: .value("Time", x), y: .value(line.name, value))
                            .foregroundStyle(line.color.opacity(0.12))
                    }
                    LineMark(
                        x: .value("Time", x),
                        y: .value(line.name, value),
                        series: .value("Series", line.name)
                    )
                    .foregroundStyle(by: .value("Series", line.name))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }

            if let hovered {
                RuleMark(x: .value("Time", hovered))
                    .foregroundStyle(Palette.gridline)
                    .annotation(position: .top, spacing: 2) {
                        Text(readout(at: hovered))
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartXScale(domain: -window...0)
        .chartYScale(domain: yDomain)
        .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Palette.gridline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(verbatim: axisFormat(number)).font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            guard let anchor = proxy.plotFrame else { return }
                            let plot = geometry[anchor]
                            guard let x = proxy.value(atX: location.x - plot.minX, as: Int.self) else { return }
                            hover.index = min(max(x, -window), 0)
                        case .ended:
                            hover.index = nil
                        }
                    }
            }
        }
        .frame(height: 58)
    }

    private var yDomain: ClosedRange<Double> {
        if let domain { return domain }
        let top = series.flatMap(\.values).max() ?? 0
        return 0...max(1, top * 1.15)
    }

    private func readout(at x: Int) -> String {
        let label = x == 0 ? "now" : "\(-x)s ago"
        let parts = series.compactMap { line -> String? in
            let index = line.values.count - 1 + x
            guard line.values.indices.contains(index) else { return nil }
            return "\(line.name) \(format(line.values[index]))"
        }
        return ([label] + parts).joined(separator: " · ")
    }
}

/// Hover position for a chart. ObservableObject instead of @State, which needs the SwiftUI macro plugin (Xcode only).
final class HoverState: ObservableObject {
    @Published var index: Int?
}

/// Per-core utilization as a row of small bars.
struct CoreBars: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                BarMark(x: .value("Core", index), y: .value("Busy", value), width: .fixed(12))
                    .foregroundStyle(color)
                    .cornerRadius(3)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 22)
    }
}

/// Used memory as one stacked bar; free space is the track. The legend names each segment.
struct MemoryBreakdownChart: View {
    let usage: MemoryUsage
    let color: Color

    var body: some View {
        Chart {
            BarMark(x: .value("Bytes", Double(usage.app)), y: .value("Memory", "Memory"), height: .fixed(20))
                .foregroundStyle(by: .value("Kind", "App"))
            BarMark(x: .value("Bytes", Double(usage.wired)), y: .value("Memory", "Memory"), height: .fixed(20))
                .foregroundStyle(by: .value("Kind", "Wired"))
            BarMark(x: .value("Bytes", Double(usage.compressed)), y: .value("Memory", "Memory"), height: .fixed(20))
                .foregroundStyle(by: .value("Kind", "Compressed"))
            BarMark(x: .value("Bytes", Double(usage.free)), y: .value("Memory", "Memory"), height: .fixed(20))
                .foregroundStyle(by: .value("Kind", "Free"))
        }
        .chartXScale(domain: 0...Double(max(usage.total, 1)))
        .chartForegroundStyleScale(
            domain: ["App", "Wired", "Compressed", "Free"],
            range: [color, color.opacity(0.65), color.opacity(0.35), Palette.gridline]
        )
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 4)
        .frame(height: 58)
    }
}

/// One-, five-, and fifteen-minute load averages, with a hairline at the core count (load equal to cores means every core is busy).
struct LoadBars: View {
    let loads: [Double]
    let cores: Int
    let color: Color

    private static let labels = ["1 min", "5 min", "15 min"]

    var body: some View {
        Chart {
            ForEach(Array(loads.prefix(3).enumerated()), id: \.offset) { index, load in
                BarMark(x: .value("Window", Self.labels[index]), y: .value("Load", load), width: .fixed(34))
                    .foregroundStyle(color)
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        Text(String(format: "%.2f", load)).font(.caption2)
                    }
            }
            RuleMark(y: .value("Cores", Double(cores)))
                .foregroundStyle(Palette.gridline)
                .lineStyle(StrokeStyle(lineWidth: 0.5))
        }
        .chartYScale(domain: 0...Double(max(cores, 1)) * 1.3)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.caption2) }
        }
        .chartYAxis(.hidden)
        .frame(height: 58)
    }
}

/// A single-value meter. The track is a lighter step of the fill color, so the empty part still reads.
struct MeterBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 10)
    }
}
