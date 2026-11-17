import AppKit
import SwiftUI
import TopdCore

/// The topd logo: an arrow rising from a bar. Drawn in code so the menu bar, the popover header, the picker,
/// and the app icon all use the same shape.
enum TopdLogo {
    /// Strokes the glyph into `rect`. Coordinates are fractions of the rect, so the glyph scales with it.
    static func drawGlyph(in rect: NSRect, color: NSColor) {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let shaft = NSBezierPath()
        shaft.move(to: point(0.5, 0.30))
        shaft.line(to: point(0.5, 0.84))

        let head = NSBezierPath()
        head.move(to: point(0.28, 0.62))
        head.line(to: point(0.5, 0.84))
        head.line(to: point(0.72, 0.62))

        let bar = NSBezierPath()
        bar.move(to: point(0.26, 0.16))
        bar.line(to: point(0.74, 0.16))

        color.setStroke()
        let weight = 0.09 * min(rect.width, rect.height)
        for path in [shaft, head, bar] {
            path.lineWidth = weight
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
}

extension MenuIcon {
    /// Menu bar image. Template, so the menu bar tints it for light and dark.
    var menuBarImage: NSImage? {
        switch self {
        case .topd:
            let side: CGFloat = 16
            let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
                TopdLogo.drawGlyph(in: rect, color: .black)
                return true
            }
            image.isTemplate = true
            return image
        default:
            let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "topd")?
                .withSymbolConfiguration(configuration)
            image?.isTemplate = true
            return image
        }
    }

    /// SwiftUI image for the popover header and the Customize dropdown. Tinted by the surrounding foreground style.
    var image: Image {
        switch self {
        case .topd:
            return Image(nsImage: menuBarImage ?? NSImage()).renderingMode(.template)
        default:
            return Image(systemName: symbol)
        }
    }
}
