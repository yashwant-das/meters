import Foundation

enum PopoverLayout: String, CaseIterable, Identifiable {
    case grouped, compact, activity
    var id: String { rawValue }

    var title: String {
        switch self {
        case .grouped: return "Grouped system panel"
        case .compact: return "Compact menu extra"
        case .activity: return "Activity Monitor miniature"
        }
    }

    var detail: String {
        switch self {
        case .grouped: return "Clear sections with every statistic visible"
        case .compact: return "A quick overview with expandable details"
        case .activity: return "Overview readings and detailed history charts"
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case text, symbols, meters
    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Refined text"
        case .symbols: return "Compact symbols"
        case .meters: return "Text with micro meters"
        }
    }

    var detail: String {
        switch self {
        case .text: return "Small text labels beside each reading"
        case .symbols: return "Monochrome SF Symbols beside each reading"
        case .meters: return "Text labels with small usage meters"
        }
    }
}

enum Prefs {
    static let iconLabelsKey = "useIconLabels"
    static let popoverLayoutKey = "popoverLayout"
    static let menuBarStyleKey = "menuBarStyle"
    static let usageColorsKey = "colorReadingsByUsage"

    /// Preserve the old icon preference only when no new style has been chosen.
    static func migrate(in defaults: UserDefaults = .standard) {
        if defaults.object(forKey: usageColorsKey) == nil {
            defaults.set(true, forKey: usageColorsKey)
        }
        if defaults.object(forKey: menuBarStyleKey) == nil {
            let style: MenuBarStyle = defaults.bool(forKey: iconLabelsKey) ? .symbols : .text
            defaults.set(style.rawValue, forKey: menuBarStyleKey)
        } else if MenuBarStyle(rawValue: defaults.string(forKey: menuBarStyleKey) ?? "") == nil {
            defaults.set(MenuBarStyle.text.rawValue, forKey: menuBarStyleKey)
        }
        if PopoverLayout(rawValue: defaults.string(forKey: popoverLayoutKey) ?? "") == nil {
            defaults.set(PopoverLayout.grouped.rawValue, forKey: popoverLayoutKey)
        }
    }
}

enum MenuBarPresentation {
    enum Level { case normal, elevated, high }

    static func fraction(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(1, max(0, value / 100))
    }

    static func percent(_ value: Double?) -> String {
        guard let fraction = fraction(value) else { return "\u{2007}--%" }
        let digits = String(Int((fraction * 100).rounded()))
        return String(repeating: "\u{2007}", count: max(0, 3 - digits.count)) + digits + "%"
    }

    static func level(_ value: Double?) -> Level {
        guard let value, value.isFinite else { return .normal }
        if value >= 80 { return .high }
        if value >= 60 { return .elevated }
        return .normal
    }
}
