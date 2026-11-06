import SwiftUI
import ServiceManagement

struct AppearanceSettingsView: View {
    @AppStorage(Prefs.popoverLayoutKey) private var layout: PopoverLayout = .grouped
    @AppStorage(Prefs.menuBarStyleKey) private var menuStyle: MenuBarStyle = .text
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    @AppStorage(Prefs.usageColorsKey) private var usageColors = true
    var onDone: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Customize").fontWeight(.semibold)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderless)
                    .accessibilityHint("Collapse customization and return to monitoring")
            }

            settingsRow("Panel layout") {
                Picker("Panel layout", selection: $layout) {
                    Text("Grouped").tag(PopoverLayout.grouped)
                    Text("Compact").tag(PopoverLayout.compact)
                    Text("Activity Monitor").tag(PopoverLayout.activity)
                }
            }
            settingsRow("Menu bar style") {
                Picker("Menu bar style", selection: $menuStyle) {
                    Text("Text").tag(MenuBarStyle.text)
                    Text("Symbols").tag(MenuBarStyle.symbols)
                    Text("Micro meters").tag(MenuBarStyle.meters)
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 5) {
                settingsToggle("Color readings by usage", isOn: $usageColors)
                Text("Orange at 60% · Red at 80%\nOff uses the standard text color.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                settingsToggle("Launch at login", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: setLaunchAtLogin
                ))

                if loginStatus == .requiresApproval {
                    Text("Allow Meters in System Settings → General → Login Items.")
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
                if let loginError {
                    Text(loginError).foregroundStyle(.red)
                }
            }
            Text("Changes apply immediately.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .controlSize(.small)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.08)) }
        .onAppear { loginStatus = SMAppService.mainApp.status }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private func settingsRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 6)
            control()
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 145, alignment: .trailing)
        }
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
        }
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
