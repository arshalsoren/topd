import AppKit
import SwiftUI
import TopdCore

/// In-popover settings. No separate window. Every control applies at once and persists.
/// Layout and styling follow macOS System Settings: a small section label, one grouped container per section,
/// separators between rows, system text styles, and semantic colors. The system accent drives switches.
struct PreferencesView: View {
    let settings: SettingsModel
    let launch: LaunchAtLogin
    let onBack: () -> Void

    /// The card being dragged, shared by the handles and the drop targets.
    @StateObject private var drag = CardDrag()
    /// Which Customize chooser is open. Shared, so only one is open at a time.
    @StateObject private var choosers = ChooserGroup()

    var body: some View {
        let preferences = settings.preferences
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                IconButton(symbol: "chevron.left", help: "Back", action: onBack)
                Text("Preferences")
                    .font(.headline)
                Spacer()
                IconButton(symbol: "power", help: "Quit topd", tint: .red) { NSApplication.shared.terminate(nil) }
            }

            SettingsSection(title: "General", footnote: launch.message) {
                SettingsRow(title: "Launch at login") {
                    SwitchControl(isOn: Binding(
                        get: { launch.state == .enabled },
                        set: { launch.setEnabled($0) }
                    ))
                }
            }

            SettingsSection(title: "Customize") {
                ChoiceRow(id: "icon", group: choosers, title: "Icon") {
                    iconPreview(preferences.menuIcon)
                }
                SettingsDivider()
                ChoiceRow(id: "theme", group: choosers, title: "Theme") {
                    themePreview(preferences.theme)
                }
                if preferences.theme == .system {
                    SettingsDivider()
                    ChoiceRow(id: "systemDark", group: choosers, title: "Dark theme") {
                        themePreview(preferences.systemDarkTheme)
                    }
                    SettingsDivider()
                    ChoiceRow(id: "systemLight", group: choosers, title: "Light theme") {
                        themePreview(preferences.systemLightTheme)
                    }
                }
            }

            SettingsSection(
                title: "At a glance",
                footnote: "Shows 1 to 3 cards with their values. Replaces the icon while on. The menu bar item widens with each card."
            ) {
                SettingsRow(title: "Show values") {
                    SwitchControl(isOn: Binding(
                        get: { preferences.glanceEnabled },
                        set: { settings.setGlanceEnabled($0) }
                    ))
                }
                SettingsDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cards to show")
                        .font(.body)
                        .foregroundStyle(preferences.glanceEnabled ? .primary : .tertiary)
                    HStack(spacing: 6) {
                        ForEach(Card.allCases, id: \.self) { card in
                            GlanceChip(
                                card: card,
                                selected: preferences.glance.contains(card),
                                enabled: preferences.glanceEnabled && preferences.cards.contains(card)
                            ) {
                                settings.toggleGlance(card)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            SettingsSection(
                title: "Cards",
                footnote: "Drag the handle to reorder. The popover follows this order. At least one card stays on."
            ) {
                let order = preferences.cardOrder
                ForEach(Array(order.enumerated()), id: \.element) { index, card in
                    CardRow(
                        card: card,
                        isOn: cardBinding(card),
                        canTurnOff: preferences.cards != [card],
                        drag: drag
                    )
                    .onDrop(of: [.text], delegate: CardDropDelegate(
                        target: card,
                        order: order,
                        drag: drag,
                        move: { source, offset in settings.moveCard(source, by: offset) }
                    ))
                    if index < order.count - 1 { SettingsDivider() }
                }
            }

            SettingsSection(title: "Processes") {
                SettingsRow(title: "Top 5 by CPU") {
                    SwitchControl(isOn: sectionBinding(.topCPU))
                }
                SettingsDivider()
                SettingsRow(title: "Top 5 by memory") {
                    SwitchControl(isOn: sectionBinding(.topMemory))
                }
            }
        }
        .onAppear { launch.refresh() }
        // The open chooser panel is drawn here, above every section, with a backdrop that closes it on an outside click.
        .overlayPreferenceValue(ChooserAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let id = choosers.openID, let anchor = anchors[id] {
                    let field = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { close() }
                        openPanel(for: id)
                            .offset(x: field.maxX - 240, y: field.maxY + 6)
                    }
                }
            }
        }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.22)) { choosers.openID = nil }
    }

    @ViewBuilder
    private func openPanel(for id: String) -> some View {
        let preferences = settings.preferences
        switch id {
        case "icon":
            ChoicePanel(options: MenuIcon.allCases, selection: preferences.menuIcon, option: { iconOption($0) }) { icon in
                settings.setMenuIcon(icon)
                close()
            }
        case "theme":
            ChoicePanel(options: AppTheme.allCases, selection: preferences.theme, option: { themeOption($0) }) { theme in
                settings.setTheme(theme)
                close()
            }
        case "systemDark":
            ChoicePanel(options: AppTheme.darkChoices, selection: preferences.systemDarkTheme, option: { themeOption($0) }) { theme in
                settings.setSystemDarkTheme(theme)
                close()
            }
        case "systemLight":
            ChoicePanel(options: AppTheme.lightChoices, selection: preferences.systemLightTheme, option: { themeOption($0) }) { theme in
                settings.setSystemLightTheme(theme)
                close()
            }
        default:
            EmptyView()
        }
    }

    private func iconPreview(_ icon: MenuIcon) -> some View {
        HStack(spacing: 6) {
            icon.image.themedSecondary()
            Text(icon.title).font(.body).themedSecondary()
        }
    }

    private func iconOption(_ icon: MenuIcon) -> some View {
        HStack(spacing: 8) {
            icon.image.frame(width: 18)
            Text(icon.title).font(.body)
        }
    }

    private func themePreview(_ theme: AppTheme) -> some View {
        HStack(spacing: 8) {
            Text(theme.title).font(.body).themedSecondary()
            ThemeSwatch(colors: theme.swatch)
        }
    }

    private func themeOption(_ theme: AppTheme) -> some View {
        HStack(spacing: 10) {
            ThemeSwatch(colors: theme.swatch)
            Text(theme.title).font(.body)
        }
    }

    private func cardBinding(_ card: Card) -> Binding<Bool> {
        Binding(
            get: { settings.preferences.cards.contains(card) },
            set: { settings.setCard(card, enabled: $0) }
        )
    }

    private func sectionBinding(_ section: ProcessSection) -> Binding<Bool> {
        Binding(
            get: { settings.preferences.sections.contains(section) },
            set: { settings.setSection(section, enabled: $0) }
        )
    }
}

/// The card being dragged. A class so the drop handler reads it at once, without waiting on async item loading.
final class CardDrag: ObservableObject {
    var card: Card?
}

/// Reorders live while the pointer moves over the list. A row moves only once the pointer crosses its midpoint
/// in the direction of travel, so the list does not flicker when the pointer sits on a boundary.
private struct CardDropDelegate: DropDelegate {
    /// Midpoint of a card row in its own coordinates (rows are 32 pt tall plus a 1 pt divider).
    private static let midpoint: CGFloat = 16

    let target: Card
    let order: [Card]
    let drag: CardDrag
    let move: (Card, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        drag.card != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let source = drag.card, source != target,
              let from = order.firstIndex(of: source), let to = order.firstIndex(of: target) else {
            return DropProposal(operation: .move)
        }
        let pastMidpoint = to > from ? info.location.y > Self.midpoint : info.location.y < Self.midpoint
        if pastMidpoint {
            withAnimation(.snappy(duration: 0.22)) {
                move(source, to - from)
            }
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        drag.card = nil
        return true
    }
}

/// A card row: a three-line drag handle, the card's symbol and title, and its ON switch.
private struct CardRow: View {
    let card: Card
    let isOn: Binding<Bool>
    let canTurnOff: Bool
    let drag: CardDrag

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.body)
                .themedTertiary()
                .frame(width: 18, height: 22)
                .contentShape(Rectangle())
                .onDrag({
                    drag.card = card
                    return NSItemProvider(object: card.rawValue as NSString)
                }, preview: {
                    CardDragPreview(card: card)
                })
                .help("Drag to reorder")
                .accessibilityLabel("Drag to reorder \(card.title)")
            Image(systemName: card.symbol)
                .font(.body)
                .themedSecondary()
                .frame(width: 18)
            Text(card.title)
                .font(.body)
            Spacer(minLength: 12)
            SwitchControl(isOn: isOn)
                .disabled(!canTurnOff && isOn.wrappedValue)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
    }
}

/// The floating image shown under the pointer while a card is dragged.
private struct CardDragPreview: View {
    let card: Card

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: card.symbol)
                .foregroundStyle(card.color)
            Text(card.title)
                .font(.body)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

/// A section label, one grouped container, and an optional footnote.
private struct SettingsSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content
    @Environment(\.themeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .themedSecondary()
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.vertical, 2)
            .background(theme?.group ?? Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(theme?.separator ?? Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .themedSecondary()
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One row: title and a control on the trailing edge.
private struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body)
            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
    }
}

private struct SettingsDivider: View {
    @Environment(\.themeColors) private var theme

    var body: some View {
        Divider()
            .overlay(theme?.separator ?? Color(nsColor: .separatorColor).opacity(0.6))
            .padding(.leading, 12)
    }
}

/// System switch, drawn in the user's accent color as in native apps.
private struct SwitchControl: View {
    let isOn: Binding<Bool>

    var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
    }
}

/// Card chip for the menu bar. Selected takes the card's own color; unselected is grayed out. No checkmark.
private struct GlanceChip: View {
    let card: Card
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: card.symbol)
                    .font(.caption.weight(.semibold))
                Text(card.title)
                    .font(.footnote)
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? card.color : Color(nsColor: .quaternaryLabelColor)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}
