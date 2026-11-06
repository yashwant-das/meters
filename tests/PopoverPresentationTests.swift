import Foundation

@main
struct PopoverPresentationTests {
    @MainActor static func main() {
        // A fixed per-layout height would fail the fitting and shrinking cases.
        assert(PopoverSizing.height(content: 400, chrome: 80, available: 700) == 480)
        assert(PopoverSizing.height(content: 800, chrome: 80, available: 500) == 500)
        assert(PopoverSizing.height(content: 250, chrome: 80, available: 700) == 330)
        assert(PopoverSizing.height(content: 400.2, chrome: 80, available: 700) == 481)
        assert(PopoverSizing.height(content: .nan, chrome: 80, available: 700) == 80)
        assert(PopoverSizing.height(content: -50, chrome: 80, available: 700) == 80)
        assert(PopoverSizing.height(content: 400, chrome: 80, available: .infinity) == 1)
        assert(PopoverSizing.height(content: 0, chrome: 0, available: 0) == 1)

        let presentation = PopoverPresentation()
        assert(!presentation.customizing)
        presentation.openCustomization()
        assert(presentation.customizing)
        let firstReveal = presentation.customizationRequest
        presentation.openCustomization()
        assert(presentation.customizationRequest != firstReveal,
               "Repeated Customize commands must reveal controls even when already expanded")
        presentation.reset()
        assert(!presentation.customizing, "Reopening should return to monitoring")
        print("Popover presentation tests passed (content sizing, screen cap, shrink, invalid values, reset)")
    }
}
