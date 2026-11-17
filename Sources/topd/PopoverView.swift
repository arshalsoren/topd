import AppKit
import SwiftUI
import TopdCore

/// Search text and sort key for the process lists. Owned by the popover state so they survive switching to Preferences.
final class ProcessFilter: ObservableObject {
    @Published var query = ""
    @Published var sort: ProcessSort = .cpu
}

/// Which screen the popover shows. Lives across openings of the popover.
final class PopoverState: ObservableObject {
    @Published var showsPreferences = false
    let filter = ProcessFilter()
}

/// Root of the popover: metrics, or the in-popover Preferences panel. Shares one glass background.
struct PopoverRoot: View {
    let settings: SettingsModel
    let monitor: Monitor
    let launch: LaunchAtLogin
    @ObservedObject var state: PopoverState
    /// macOS light or dark, as the popover currently sees it. Used only by the System theme.
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        // System resolves to the dark or light choice for the current macOS appearance. Other themes resolve to themselves.
        let preferences = settings.preferences
        let resolved = preferences.resolvedTheme(isDark: systemScheme == .dark)
        let theme = resolved.colors
        // Draw the content in the palette's own scheme, so system text and controls match the chosen theme.
        let scheme: ColorScheme = resolved == .glass ? systemScheme : (resolved.isDark ? .dark : .light)
        Group {
            if state.showsPreferences {
                PreferencesView(settings: settings, launch: launch) { state.showsPreferences = false }
            } else {
                PopoverView(settings: settings, monitor: monitor, filter: state.filter) { state.showsPreferences = true }
            }
        }
        .padding(14)
        .frame(width: state.showsPreferences ? PopoverLayout.preferencesWidth : PopoverLayout.width(
            cards: settings.preferences.orderedCards.count,
            showsProcesses: !settings.preferences.sections.isEmpty
        ), alignment: .topLeading)
        .background {
            if let theme {
                theme.background.ignoresSafeArea()
            } else {
                VisualEffectBackground().ignoresSafeArea()
            }
        }
        .environment(\.themeColors, theme)
        .environment(\.colorScheme, scheme)
        .tint(theme?.accent)
        .foregroundStyle(theme?.text ?? .primary)
    }
}

struct PopoverView: View {
    let settings: SettingsModel
    let monitor: Monitor
    @ObservedObject var filter: ProcessFilter
    let onPreferences: () -> Void


    var body: some View {
        let preferences = settings.preferences
        VStack(alignment: .leading, spacing: 12) {
            Header(icon: preferences.menuIcon, onPreferences: onPreferences)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PopoverLayout.spacing), count: PopoverLayout.columns(for: preferences.orderedCards.count)), spacing: PopoverLayout.spacing) {
                ForEach(preferences.orderedCards, id: \.self) { card in
                    CardView(card: card, monitor: monitor)
                }
            }

            if !preferences.sections.isEmpty {
                ProcessToolbar(query: $filter.query, sort: $filter.sort)
                let matches = ProcessRanking.filter(monitor.processes, query: filter.query)
                let sort = filter.sort
                ForEach(ProcessSection.allCases.filter { preferences.sections.contains($0) }, id: \.self) { section in
                    ProcessListView(
                        section: section,
                        rows: ProcessRanking.sorted(
                            section == .topCPU ? ProcessRanking.topByCPU(matches) : ProcessRanking.topByMemory(matches),
                            by: sort
                        )
                    )
                }
            }
        }
    }
}

private struct Header: View {
    /// The menu bar icon the user chose in Customize, so the header matches the item.
    let icon: MenuIcon
    let onPreferences: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            icon.image
                .themedSecondary()
            Text("topd")
                .font(.headline)
            Spacer()
            IconButton(symbol: "gearshape", help: "Preferences", action: onPreferences)
            IconButton(symbol: "power", help: "Quit topd", tint: .red) { NSApplication.shared.terminate(nil) }
        }
    }
}

/// Search filters the whole process list. Each section picks its top five from the filtered list; the sort key orders the rows shown.
struct ProcessToolbar: View {
    @Binding var query: String
    @Binding var sort: ProcessSort
    @Environment(\.themeColors) private var theme

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .themedSecondary()
                // Our own placeholder, in the theme's tertiary color. The AppKit placeholder ignores the prompt color on macOS.
                ZStack(alignment: .leading) {
                    TextField("", text: $query)
                        .foregroundStyle(theme?.text ?? .primary)
                        .tint(theme?.accent)
                        .textFieldStyle(.plain)
                    // On top of the field so it shows whatever the field draws, and it passes clicks through to the field.
                    if query.isEmpty {
                        Text("Search name or PID")
                            .themedTertiary()
                            .allowsHitTesting(false)
                    }
                }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").themedTertiary()
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.quaternary))

            PillControl(options: ProcessSort.allCases, selection: $sort, title: \.title)
                .frame(width: 250)
        }
    }
}

/// A capsule segmented control. The selected segment slides between options.
struct PillControl<Value: Hashable>: View {
    @Environment(\.themeColors) private var theme
    let options: [Value]
    @Binding var selection: Value
    let title: KeyPath<Value, String>

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selection = option }
                } label: {
                    Text(option[keyPath: title])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selected ? (theme?.text ?? Color.primary) : (theme?.secondary ?? Color.secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(theme?.accent.opacity(0.22) ?? Color(nsColor: .controlBackgroundColor))
                                    .matchedGeometryEffect(id: "selection", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.quaternary))
    }
}

/// A small round icon button. Quit uses the red tint.
struct IconButton: View {
    let symbol: String
    let help: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint == .primary ? AnyShapeStyle(.quaternary) : AnyShapeStyle(tint.opacity(0.18))))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ProcessListView: View {
    let section: ProcessSection
    let rows: [ProcessRow]

    private var title: String {
        section == .topCPU ? "Top 5 by CPU" : "Top 5 by memory"
    }

    private var color: Color {
        Palette.slot(section == .topCPU ? 1 : 3)
    }

    var body: some View {
        // The bar scale is the largest value in this list, so the longest bar is always the top process.
        let peak = section == .topCPU
            ? rows.map(\.cpuPercent).max() ?? 0
            : Double(rows.map(\.memoryBytes).max() ?? 0)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .themedSecondary()
                Spacer()
                Text("CPU").frame(width: 60, alignment: .trailing)
                Text("Memory").frame(width: 72, alignment: .trailing)
            }
            .font(.caption)
            .themedTertiary()
            .padding(.horizontal, 6)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                ProcessRowView(row: row, section: section, peak: peak, color: color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quinary.opacity(index.isMultiple(of: 2) ? 1 : 0))
                    )
            }

            if rows.isEmpty {
                Text("No matching processes")
                    .font(.caption)
                    .themedSecondary()
                    .padding(.horizontal, 6)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

struct ProcessRowView: View {
    let row: ProcessRow
    let section: ProcessSection
    let peak: Double
    let color: Color

    private var fraction: Double {
        guard peak > 0 else { return 0 }
        let value = section == .topCPU ? row.cpuPercent : Double(row.memoryBytes)
        return min(max(value / peak, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(row.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 170, alignment: .leading)
            Text(verbatim: "\(row.pid)")
                .font(.caption.monospacedDigit())
                .themedSecondary()
                .frame(width: 44, alignment: .trailing)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text(Format.percent(row.cpuPercent))
                .font(.callout.monospacedDigit())
                .frame(width: 60, alignment: .trailing)
            Text(Format.bytes(row.memoryBytes))
                .font(.callout.monospacedDigit())
                .frame(width: 72, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Native translucent material behind the popover, the same family Maccy uses.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Popover width follows the cards that are on: one column per card, up to three. Process lists need a readable minimum.
enum PopoverLayout {
    static let cardWidth: CGFloat = 210
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 14
    static let processMinWidth: CGFloat = 460
    static let preferencesWidth: CGFloat = 660

    static func columns(for cards: Int) -> Int {
        min(3, max(1, cards))
    }

    static func width(cards: Int, showsProcesses: Bool) -> CGFloat {
        let count = CGFloat(columns(for: cards))
        let grid = count * cardWidth + (count - 1) * spacing + 2 * padding
        return showsProcesses ? max(grid, processMinWidth) : grid
    }
}
