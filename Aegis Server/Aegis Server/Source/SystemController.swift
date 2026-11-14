import Foundation
import Combine

// Runs every shell command (pmset, caffeinate) and publishes the results to the UI.
@MainActor
final class SystemController: ObservableObject {
    @Published var sleepDisabled = false
    @Published var lidAwake = false
    @Published var wifiAlwaysOn = false
    @Published var onBattery = false
    @Published var lastError = ""

    private var caffeinateProcess: Process?

    // MARK: - pmset toggles (password asked only the first time, then remembered)

    func setSleepDisabled(_ on: Bool) {
        Task {
            if on { setLidAwake(false) }   // the two awake modes are exclusive
            let ok = await runPmset(["-a", "disablesleep", on ? "1" : "0"])
            lastError = ok ? "" : "Password was cancelled — setting not changed."
            await refreshStatus()
        }
    }

    // macOS turns the Wi-Fi radio down when the lid closes; these settings tell it not to.
    func setWifiAlwaysOn(_ on: Bool) {
        Task {
            var ok = true
            if on {
                ok = await runPmset(["-a", "networkoversleep", "1"])
                if ok { ok = await runPmset(["-a", "tcpkeepalive", "1"]) }
                if ok { ok = await runPmset(["-a", "powernap", "1"]) }
            } else {
                ok = await runPmset(["-a", "networkoversleep", "0"])
            }
            lastError = ok ? "" : "Password was cancelled — setting not changed."
            await refreshStatus()
        }
    }

    // Runs pmset as root. The first time it asks for the password once and adds a
    // sudoers rule, so every later run is instant and password-free.
    private func runPmset(_ args: [String]) async -> Bool {
        var code = Self.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + args).code
        if code != 0 {
            let cmd = "echo '%admin ALL=(root) NOPASSWD: /usr/bin/pmset' > /etc/sudoers.d/aegis-server"
                + " && chmod 0440 /etc/sudoers.d/mimi-server"
                + " && visudo -cf /etc/sudoers.d/mimi-server"
            let (_, setup) = Self.run("/usr/bin/osascript",
                                      ["-e", "do shell script \"\(cmd)\" with administrator privileges"])
            if setup == 0 {
                code = Self.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + args).code
            }
        }
        return code == 0
    }

    // Reads the real state back from pmset -g so the switches always show the truth.
    func refreshStatus() async {
        let (out, _) = Self.run("/usr/bin/pmset", ["-g"])
        func isOn(_ key: String) -> Bool {
            let line = out.split(separator: "\n").first {
                $0.range(of: key, options: .caseInsensitive) != nil
            }
            guard let line, let v = line.split(whereSeparator: \.isWhitespace).last else { return false }
            return v == "1"
        }
        sleepDisabled = isOn("SleepDisabled")
        wifiAlwaysOn = isOn("networkoversleep")
        let (batt, _) = Self.run("/usr/bin/pmset", ["-g", "batt"])
        onBattery = !batt.contains("AC Power")
    }

    // MARK: - caffeinate (lid open)

    func setLidAwake(_ on: Bool) {
        guard on != lidAwake else { return }
        lidAwake = on
        if on {
            // the two awake modes are exclusive: switching to lid-open clears lid-closed
            if sleepDisabled {
                Task {
                    let ok = await runPmset(["-a", "disablesleep", "0"])
                    if !ok { lastError = "Password was cancelled — setting not changed." }
                    await refreshStatus()
                }
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            p.arguments = ["-i"]
            do { try p.run(); caffeinateProcess = p; lastError = "" }
            catch { lastError = "Could not start caffeinate: \(error.localizedDescription)" }
        } else {
            caffeinateProcess?.terminate()
            caffeinateProcess = nil
        }
    }

    // Synchronous shell helper; safe to call from any thread.
    nonisolated private static func run(_ path: String, _ args: [String]) -> (out: String, code: Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return ("\(error.localizedDescription)", -1) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "", p.terminationStatus)
    }
}
