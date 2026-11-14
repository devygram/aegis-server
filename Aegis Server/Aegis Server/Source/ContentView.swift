import SwiftUI
import ServiceManagement

// The little window that opens from the menu bar: compact switches with one-line help text.
struct ContentView: View {
    @StateObject private var sys = SystemController()
    @State private var startAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.pink)
                Text("Aegis Server").font(.headline)
            }

            if !sys.lastError.isEmpty {
                Text(sys.lastError).font(.caption).foregroundStyle(.red)
            }

            option(
                title: "Keep Mac Awake (lid open)",
                help: "Prevents idle sleep while you're working. No password needed.",
                isOn: Binding(get: { sys.lidAwake }, set: { sys.setLidAwake($0) }),
                stateOn: sys.lidAwake)

            Divider()

            option(
                title: "Keep Mac Awake (lid closed)",
                help: "Keeps the Mac running after you close the lid. Turns off the lid-open switch.",
                isOn: Binding(get: { sys.sleepDisabled }, set: { sys.setSleepDisabled($0) }),
                stateOn: sys.sleepDisabled)

            if sys.sleepDisabled && sys.onBattery {
                Text("⚠️ On battery — lid-closed mode drains it fast. Plug in if you can.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            option(
                title: "Keep Wi-Fi connected (lid closed)",
                help: "Stops Wi-Fi from dropping when the lid is closed, and reconnects it automatically if it does.",
                isOn: Binding(get: { sys.wifiAlwaysOn }, set: { sys.setWifiAlwaysOn($0) }),
                stateOn: sys.wifiAlwaysOn)

            if !sys.lastGuardAction.isEmpty && sys.wifiAlwaysOn {
                Text(sys.lastGuardAction).font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button(sys.updateAvailable ? "Update Now" : "Check for Updates") { sys.checkForUpdates() }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(sys.updateAvailable ? .green : .primary)
                if !sys.updateStatus.isEmpty {
                    Text(sys.updateStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Toggle("Start at Login", isOn: Binding(
                    get: { startAtLogin },
                    set: { on in
                        startAtLogin = on
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }))
                    .font(.callout)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Label("Quit", systemImage: "power")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 330)
        .task { await sys.refreshStatus() }
    }

    // One compact switch row: title, short help, and a small active/inactive dot.
    private func option(title: String, help: String, isOn: Binding<Bool>, stateOn: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(stateOn ? Color.green : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                    Text(title).font(.callout)
                }
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize()
        }
    }
}
