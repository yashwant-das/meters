import SwiftUI
import Combine

/// Transient presentation state shared by menu commands and the mounted dashboard.
@MainActor
final class PopoverPresentation: ObservableObject {
    @Published var customizing = false
    @Published var maximumHeight: CGFloat = 700
    @Published private(set) var customizationRequest = 0

    func openCustomization() {
        customizing = true
        // A repeated command must reveal an already-expanded card scrolled out of view.
        customizationRequest &+= 1
    }
    func reset() { customizing = false }
}

enum PopoverSizing {
    static func height(content: CGFloat, chrome: CGFloat, available: CGFloat) -> CGFloat {
        let content = content.isFinite ? max(0, content) : 0
        let chrome = chrome.isFinite ? max(0, chrome) : 0
        let available = available.isFinite ? max(1, available) : 1
        return min(available, max(1, ceil(content + chrome)))
    }
}
