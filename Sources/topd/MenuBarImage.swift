import AppKit
import TopdCore

/// Draws the menu bar item as one template image. Every value slot is as wide as the widest value any card can show,
/// and the item reserves one slot per selected card. Values change inside their slots, so the width changes only when the selection does.
enum MenuBarImage {
    private static let height: CGFloat = 18
    private static let iconSize: CGFloat = 12
    private static let iconGap: CGFloat = 4
    private static let slotGap: CGFloat = 12
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    private static let valueWidth: CGFloat = ["100%", "9.99", "999K↓"]
        .map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }
        .max() ?? 40
    private static let slotWidth = iconSize + iconGap + valueWidth

    /// Width for a selection: one slot per card, with gaps between slots.
    static func width(forCardCount count: Int) -> CGFloat {
        let slots = max(count, 1)
        return CGFloat(slots) * slotWidth + CGFloat(slots - 1) * slotGap
    }

    /// The chosen cards, one slot each. The width follows the number of cards, not the values.
    static func glance(_ cards: [Card], snapshot: SystemSnapshot) -> NSImage {
        let image = NSImage(size: NSSize(width: width(forCardCount: cards.count), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for card in cards {
                drawSymbol(card.symbol, in: NSRect(x: x, y: (height - iconSize) / 2, width: iconSize, height: iconSize))
                let text = NSAttributedString(
                    string: card.glanceText(snapshot),
                    attributes: [.font: font, .foregroundColor: NSColor.black]
                )
                // Values are right-aligned in their slot, so a shorter value moves only the left edge.
                text.draw(at: NSPoint(
                    x: x + iconSize + iconGap + valueWidth - text.size().width,
                    y: (height - text.size().height) / 2
                ))
                x += slotWidth + slotGap
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawSymbol(_ name: String, in rect: NSRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)?
            .draw(in: rect)
    }
}
