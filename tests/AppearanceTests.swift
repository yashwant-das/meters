import AppKit

@main
struct AppearanceTests {
    @MainActor
    static func main() {
        let suite = "MetersAppearanceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        Prefs.migrate(in: defaults)
        assert(defaults.string(forKey: Prefs.popoverLayoutKey) == PopoverLayout.grouped.rawValue)
        assert(defaults.string(forKey: Prefs.menuBarStyleKey) == MenuBarStyle.text.rawValue)
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: Prefs.iconLabelsKey)
        Prefs.migrate(in: defaults)
        assert(defaults.string(forKey: Prefs.menuBarStyleKey) == MenuBarStyle.symbols.rawValue)

        // Explicit choices survive migration and do not change one another.
        for layout in PopoverLayout.allCases {
            for style in MenuBarStyle.allCases {
                defaults.set(layout.rawValue, forKey: Prefs.popoverLayoutKey)
                defaults.set(style.rawValue, forKey: Prefs.menuBarStyleKey)
                Prefs.migrate(in: defaults)
                assert(defaults.string(forKey: Prefs.popoverLayoutKey) == layout.rawValue)
                assert(defaults.string(forKey: Prefs.menuBarStyleKey) == style.rawValue)
            }
        }
        defaults.set("obsolete", forKey: Prefs.popoverLayoutKey)
        defaults.set("obsolete", forKey: Prefs.menuBarStyleKey)
        Prefs.migrate(in: defaults)
        assert(defaults.string(forKey: Prefs.popoverLayoutKey) == PopoverLayout.grouped.rawValue)
        assert(defaults.string(forKey: Prefs.menuBarStyleKey) == MenuBarStyle.text.rawValue)

        assert(MenuBarPresentation.percent(nil).contains("--%"))
        assert(MenuBarPresentation.percent(.nan).contains("--%"))
        assert(MenuBarPresentation.percent(.infinity).contains("--%"))
        assert(MenuBarPresentation.percent(-10).contains("0%"))
        assert(MenuBarPresentation.percent(130) == "100%")
        assert(MenuBarPresentation.fraction(nil) == nil)
        assert(MenuBarPresentation.fraction(.nan) == nil)
        assert(MenuBarPresentation.fraction(-10) == 0)
        assert(MenuBarPresentation.fraction(130) == 1)
        assert(MenuBarPresentation.level(59.9) == .normal)
        assert(MenuBarPresentation.level(60) == .elevated)
        assert(MenuBarPresentation.level(80) == .high)
        assert(MenuBarPresentation.level(nil) == .normal)

        for style in MenuBarStyle.allCases {
            let title = MenuBarRenderer.title(cpu: 10, ram: 39, gpu: 4, style: style)
            let string = title.string
            assert(string.range(of: "10%")!.lowerBound < string.range(of: "4%")!.lowerBound)
            assert(string.range(of: "4%")!.lowerBound < string.range(of: "39%")!.lowerBound,
                   "Menu order must be CPU, GPU, RAM for \(style)")
            let systemFont = NSFont.menuBarFont(ofSize: 0)
            title.enumerateAttribute(.font, in: NSRange(location: 0, length: title.length)) { value, _, _ in
                guard let font = value as? NSFont else { return }
                assert(font.familyName == systemFont.familyName, "Use the macOS menu bar font, not SF Mono")
                assert(font.pointSize == systemFont.pointSize, "Match the macOS menu bar text size")
            }
        }

        // Check actual AppKit widths, including transitions through three digits.
        for style in MenuBarStyle.allCases {
            let widths = [nil, 0.0, 9.0, 99.0, 100.0].map { value in
                MenuBarRenderer.title(cpu: value, ram: value, gpu: value, style: style).size().width
            }
            assert((widths.max()! - widths.min()!) < 0.5, "Menu width changed for \(style): \(widths)")
        }
        let text = MenuBarRenderer.title(cpu: 10, ram: 39, gpu: nil, style: .text)
        assert(!text.string.contains("|"))
        assert(text.string.contains("CPU") && text.string.contains("RAM") && text.string.contains("GPU"))
        for style in [MenuBarStyle.symbols, .meters] {
            let title = MenuBarRenderer.title(cpu: 10, ram: 39, gpu: nil, style: style)
            var count = 0
            title.enumerateAttribute(.attachment, in: NSRange(location: 0, length: title.length)) { value, _, _ in
                if let attachment = value as? NSTextAttachment {
                    count += 1
                    if style == .symbols {
                        assert(attachment.bounds.height >= 15, "Symbols should be sized like macOS status icons")
                        if let image = attachment.image {
                            let nativeRatio = image.size.width / image.size.height
                            let displayedRatio = attachment.bounds.width / attachment.bounds.height
                            assert(abs(nativeRatio - displayedRatio) < 0.01, "Preserve each SF Symbol’s proportions")
                        }
                    }
                }
            }
            assert(count == 3, "Expected one attachment per metric")
        }
        print("Appearance tests passed (migration, 9 preference combinations, formatting, stable widths, styles)")
    }
}
