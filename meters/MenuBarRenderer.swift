import AppKit
import CoreText

@MainActor
enum MenuBarRenderer {
    static let symbolHeight: CGFloat = 16

    static func title(cpu: Double?, ram: Double?, gpu: Double?, style: MenuBarStyle) -> NSAttributedString {
        let systemFont = NSFont.menuBarFont(ofSize: 0)
        let digitDescriptor = systemFont.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
            ]]
        ])
        let digitFont = NSFont(descriptor: digitDescriptor, size: systemFont.pointSize) ?? systemFont
        let label: [NSAttributedString.Key: Any] = [
            .font: systemFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let result = NSMutableAttributedString()
        for (name, symbol, value) in [("CPU", "cpu", cpu), ("GPU", "display", gpu), ("RAM", "memorychip", ram)] {
            if result.length > 0 { result.append(NSAttributedString(string: "   ", attributes: label)) }
            if style == .symbols, let image = symbolImage(symbol) {
                let width = symbolHeight * image.size.width / image.size.height
                let baseline = (systemFont.capHeight - symbolHeight) / 2
                result.append(attachment(image, width: width, height: symbolHeight, baseline: baseline))
                result.append(NSAttributedString(string: " ", attributes: label))
            } else {
                result.append(NSAttributedString(string: name + " ", attributes: label))
            }
            if style == .meters {
                result.append(attachment(meterImage(value), width: 4, height: 12))
                result.append(NSAttributedString(string: " ", attributes: label))
            }
            // Figure spaces/dashes occupy digit widths without changing the system typeface.
            let reading = MenuBarPresentation.percent(value).replacingOccurrences(of: "--", with: "\u{2012}\u{2012}")
            result.append(NSAttributedString(string: reading, attributes: [
                .font: digitFont,
                .kern: 0,
                .ligature: 0,
                .foregroundColor: color(value)
            ]))
        }
        return result
    }

    private static func color(_ value: Double?) -> NSColor {
        switch MenuBarPresentation.level(value) {
        case .normal: return .labelColor
        case .elevated: return .systemOrange
        case .high: return .systemRed
        }
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolHeight, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
        return NSImage(systemSymbolName: name, accessibilityDescription: name)?.withSymbolConfiguration(configuration)
    }

    private static func attachment(_ image: NSImage, width: CGFloat, height: CGFloat, baseline: CGFloat = -2) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: baseline, width: width, height: height)
        return NSAttributedString(attachment: attachment)
    }

    private static func meterImage(_ value: Double?) -> NSImage {
        let fraction = MenuBarPresentation.fraction(value)
        let image = NSImage(size: NSSize(width: 4, height: 12), flipped: false) { rect in
            NSColor.labelColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            if let fraction, fraction > 0 {
                color(value).setFill()
                NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 4, height: max(1, 12 * fraction)),
                             xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        return image
    }
}
