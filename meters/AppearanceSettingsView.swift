import SwiftUI
import ServiceManagement

struct AppearanceSettingsView: View {
    @AppStorage(Prefs.popoverLayoutKey) private var layout: PopoverLayout = .grouped
    @AppStorage(Prefs.menuBarStyleKey) private var menuStyle: MenuBarStyle = .text
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Appearance").font(.system(size: 24, weight: .bold))
                    Text("Choose how Meters looks in your menu bar and popover.")
                        .foregroundStyle(.secondary)
                }

                settingsGroup("Popover layout") {
                    Picker("Popover layout", selection: $layout) {
                        ForEach(PopoverLayout.allCases) { option in
                            optionLabel(option.title, detail: option.detail).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                settingsGroup("Menu bar style") {
                    Picker("Menu bar style", selection: $menuStyle) {
                        ForEach(MenuBarStyle.allCases) { option in
                            optionLabel(option.title, detail: option.detail).tag(option)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Divider().padding(.vertical, 6)
                    menuPreview
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                        .accessibilityLabel("Menu bar style preview")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Launch at login")
                        Spacer()
                        Toggle("Launch at login", isOn: Binding(
                            get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                            set: setLaunchAtLogin
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }

                    if loginStatus == .requiresApproval {
                        Text("Allow Meters in System Settings → General → Login Items.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Open Login Items Settings…") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                    if let loginError {
                        Text(loginError).font(.caption).foregroundStyle(.red)
                    }
                }

                Text("Changes apply immediately. Appearance follows macOS.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 560, height: min(690, (NSScreen.main?.visibleFrame.height ?? 850) - 100))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private func optionLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 4, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var menuPreview: some View {
        HStack(spacing: 16) {
            previewMetric("CPU", symbol: "cpu", value: 10)
            previewMetric("GPU", symbol: "display", value: 4)
            previewMetric("RAM", symbol: "memorychip", value: 39)
        }
    }

    private func previewMetric(_ title: String, symbol: String, value: Double) -> some View {
        HStack(spacing: 4) {
            if menuStyle == .symbols {
                Image(systemName: symbol)
                    .font(.system(size: MenuBarRenderer.symbolHeight, weight: .regular))
                    .foregroundStyle(.primary)
            } else {
                Text(title).foregroundStyle(.secondary)
            }
            if menuStyle == .meters {
                ZStack(alignment: .bottom) {
                    Capsule().fill(.primary.opacity(0.12))
                    Capsule().fill(.primary).frame(height: max(1, 12 * value / 100))
                }
                .frame(width: 3, height: 12)
            }
            Text("\(Int(value))%").monospacedDigit()
        }
        .font(Font(NSFont.menuBarFont(ofSize: 0)))
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Couldn’t update launch at login: \(error.localizedDescription)"
        }
        loginStatus = SMAppService.mainApp.status
    }
}
