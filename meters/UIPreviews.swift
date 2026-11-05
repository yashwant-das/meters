#if DEBUG
import SwiftUI
import AppKit

/// Canvas preferences live in separate suites so previews never overwrite the app's choices.
private enum PreviewPreferences {
    static func store(_ name: String, layout: PopoverLayout = .grouped) -> UserDefaults {
        let store = UserDefaults(suiteName: "Meters.Canvas.\(name)")!
        store.set(layout.rawValue, forKey: Prefs.popoverLayoutKey)
        store.set(MenuBarStyle.text.rawValue, forKey: Prefs.menuBarStyleKey)
        return store
    }
}

private struct PopoverCanvas: View {
    let layout: PopoverLayout
    let scheme: ColorScheme
    @StateObject private var monitor = SystemMonitor()

    var body: some View {
        StatsView(monitor: monitor, openSettings: {})
            .defaultAppStorage(PreviewPreferences.store("\(layout.rawValue)-\(scheme)", layout: layout))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
            .preferredColorScheme(scheme)
    }
}

/// Render the actual AppKit status title, including the correctly sized symbol attachments.
private struct MenuBarCanvasTitle: NSViewRepresentable {
    let style: MenuBarStyle

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithAttributedString: title)
        field.isSelectable = false
        field.lineBreakMode = .byClipping
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.attributedStringValue = title
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        nsView.fittingSize
    }

    private var title: NSAttributedString {
        MenuBarRenderer.title(cpu: 10, ram: 39, gpu: 4, style: style)
    }
}

private struct MenuBarCanvas: View {
    let scheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(MenuBarStyle.allCases) { style in
                VStack(alignment: .leading, spacing: 8) {
                    Text(style.title).font(.caption).foregroundStyle(.secondary)
                    MenuBarCanvasTitle(style: style)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(scheme)
    }
}

#Preview("Grouped · Light", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .grouped, scheme: .light)
}

#Preview("Grouped · Dark", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .grouped, scheme: .dark)
}

#Preview("Compact · Light", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .compact, scheme: .light)
}

#Preview("Compact · Dark", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .compact, scheme: .dark)
}

#Preview("Activity Monitor · Light", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .activity, scheme: .light)
}

#Preview("Activity Monitor · Dark", traits: .sizeThatFitsLayout) {
    PopoverCanvas(layout: .activity, scheme: .dark)
}

#Preview("Menu bar · Light", traits: .sizeThatFitsLayout) {
    MenuBarCanvas(scheme: .light)
}

#Preview("Menu bar · Dark", traits: .sizeThatFitsLayout) {
    MenuBarCanvas(scheme: .dark)
}

#Preview("Settings · Light", traits: .sizeThatFitsLayout) {
    AppearanceSettingsView()
        .defaultAppStorage(PreviewPreferences.store("settings-light"))
        .preferredColorScheme(.light)
        .allowsHitTesting(false)
}

#Preview("Settings · Dark", traits: .sizeThatFitsLayout) {
    AppearanceSettingsView()
        .defaultAppStorage(PreviewPreferences.store("settings-dark"))
        .preferredColorScheme(.dark)
        .allowsHitTesting(false)
}
#endif
