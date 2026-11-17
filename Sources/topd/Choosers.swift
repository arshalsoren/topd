import SwiftUI
import TopdCore

/// Which chooser is open. One shared value, so opening one closes the others. A class, because the app avoids @State.
final class ChooserGroup: ObservableObject {
    @Published var openID: String?
}

/// Where each chooser field sits, so its open panel can be drawn at the top of the Preferences view.
struct ChooserAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// A settings row with a dropdown field on the trailing edge. The panel itself is drawn by the parent, above every section.
struct ChoiceRow<Preview: View>: View {
    let id: String
    @ObservedObject var group: ChooserGroup
    let title: String
    @ViewBuilder let content: () -> Preview

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body)
            Spacer(minLength: 12)
            ChoiceField(isOpen: group.openID == id) {
                withAnimation(.snappy(duration: 0.22)) {
                    group.openID = group.openID == id ? nil : id
                }
            } content: {
                content()
            }
            .anchorPreference(key: ChooserAnchorKey.self, value: .bounds) { [id: $0] }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
    }
}

/// The closed dropdown: the current value and an up-down chevron, in a quiet rounded field.
struct ChoiceField<Content: View>: View {
    let isOpen: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                content
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .themedSecondary()
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isOpen ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The floating panel of options.
struct ChoicePanel<Value: Hashable, Option: View>: View {
    let options: [Value]
    let selection: Value
    let option: (Value) -> Option
    let onSelect: (Value) -> Void
    @Environment(\.themeColors) private var theme

    var body: some View {
        // Every option is shown, with no scrolling: twelve themes fit below the Customize section.
        VStack(spacing: 2) {
            ForEach(options, id: \.self) { value in
                ChoiceOption(selected: value == selection, action: { onSelect(value) }) {
                    option(value)
                }
            }
        }
        .padding(6)
        .frame(width: 240)
        // Opaque, so text from the sections behind never shows through the options.
        .background(theme?.group ?? Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

/// Hover state for one option row.
private final class RowHover: ObservableObject {
    @Published var isHovered = false
}

/// One row in the panel. Hover tints it; the selected option gets an accent wash and a check.
private struct ChoiceOption<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    @StateObject private var hover = RowHover()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(rowFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovered = $0 }
    }

    private var rowFill: AnyShapeStyle {
        if selected { return AnyShapeStyle(Color.accentColor.opacity(0.18)) }
        if hover.isHovered { return AnyShapeStyle(.quaternary) }
        return AnyShapeStyle(Color.clear)
    }
}

/// Three overlapping dots that stand for a theme. Each dot has a hairline ring so dark colors stay visible on dark rows.
struct ThemeSwatch: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: -4) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
            }
        }
    }
}
