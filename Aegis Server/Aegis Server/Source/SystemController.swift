import Foundation
import AppKit
import Combine

// Runs every shell command (pmset, networksetup, caffeinate) and publishes the results to the UI.
@MainActor
final class SystemController: ObservableObject {
    @Published var sleepDisabled = false
    @Published var lidAwake = false
    @Published var wifiAlwaysOn = false
    @Published var onBattery = false
    @Published var lastError = ""
    @Published var lastGuardAction = ""

    private var caffeinateProcess: Process?
    private var watchdogTask: Task<Void, Never>?
    private var lastCycle = Date.distantPast

    // Checks GitHub for a newer release shortly after launch, so the answer is
    // ready when the user opens the menu. Never opens anything by itself.
    init() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self?.checkForUpdates(autoOpen: false)
        }
    }

    // MARK: - pmset toggles (password asked only the first time, then remembered)

    func setSleepDisabled(_ on: Bool) {
        Task {
            if on { setLidAwake(false) }   // the two awake modes are exclusive
            let ok = await runPmset(["-a", "disablesleep", on ? "1" : "0"])
            if ok { UserDefaults.standard.set(on, forKey: "sleepSet") }
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
                if ok { await ensureNetworksetupPermission() }
                if ok { startWatchdog() }
            } else {
                stopWatchdog()
                ok = await runPmset(["-a", "networkoversleep", "0"])
            }
            lastError = ok ? "" : "Password was cancelled — setting not changed."
            if ok { UserDefaults.standard.set(on, forKey: "wifiSet") }
            await refreshStatus()
        }
    }

    // MARK: - Wi-Fi watchdog

    // Every few seconds: if Wi-Fi is powered on but has lost its connection,
    // briefly power-cycle the radio so macOS auto-joins the saved network again.
    private func startWatchdog() {
        guard watchdogTask == nil else { return }
        watchdogTask = Task {
            while !Task.isCancelled && wifiAlwaysOn {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard wifiAlwaysOn else { break }
                guard Date().timeIntervalSince(lastCycle) > 20 else { continue }
                await guardOnce()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    private func guardOnce() async {
        let dev = await wifiDevice()
        let (power, _) = Self.run("/bin/sh", ["-c",
            "/usr/bin/sudo -n /usr/sbin/networksetup -getairportpower \(dev) 2>/dev/null"])
        guard power.contains("On") else { return }          // user turned Wi-Fi off themselves
        let (assoc, code) = Self.run("/bin/sh", ["-c",
            "/usr/bin/sudo -n /usr/sbin/networksetup -getairportnetwork \(dev) 2>/dev/null"])
        guard code == 0, !(assoc.contains("not set") || assoc.isEmpty) else { return }  // no permission yet
        guard !assoc.contains("Current Wi-Fi Network:") || assoc.contains("not set") else { return } // still connected
        lastCycle = Date()
        let (_, cycle) = Self.run("/bin/sh", ["-c",
            "/usr/bin/sudo -n /usr/sbin/networksetup -setairportpower \(dev) off; sleep 2; /usr/bin/sudo -n /usr/sbin/networksetup -setairportpower \(dev) on"])
        if cycle == 0 {
            let time = Date().formatted(date: .omitted, time: .shortened)
            lastGuardAction = "Reconnected Wi-Fi at \(time)"
        }
    }

    // Finds which interface (en0, en1...) is the Wi-Fi one on this Mac.
    private func wifiDevice() async -> String {
        let (ports, _) = Self.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        let lines = ports.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        for (i, line) in lines.enumerated() where line.hasPrefix("Hardware Port: Wi-Fi") {
            if i + 1 < lines.count, let d = lines[i + 1].split(separator: " ").last { return String(d) }
        }
        return "en0"
    }

    // MARK: - privileged helpers (password asked only the first time, then remembered)

    // Runs pmset as root. The first time it asks for the password once and adds a
    // sudoers rule, so every later run is instant and password-free.
    private func runPmset(_ args: [String]) async -> Bool {
        var code = Self.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + args).code
        if code != 0 {
            await ensurePrivileges()
            code = Self.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset"] + args).code
        }
        return code == 0
    }

    // Makes sure the watchdog's networksetup calls are password-free too.
    private func ensureNetworksetupPermission() async {
        let probe = Self.run("/usr/bin/sudo", ["-n", "/usr/sbin/networksetup", "-listallhardwareports"])
        if probe.code != 0 { await ensurePrivileges() }
    }

    private func ensurePrivileges() async {
        let cmd = "echo '%admin ALL=(root) NOPASSWD: /usr/bin/pmset' > /etc/sudoers.d/aegis-server"
            + " && echo '%admin ALL=(root) NOPASSWD: /usr/sbin/networksetup' >> /etc/sudoers.d/aegis-server"
            + " && chmod 0440 /etc/sudoers.d/aegis-server"
            + " && visudo -cf /etc/sudoers.d/aegis-server"
        _ = Self.run("/usr/bin/osascript",
                     ["-e", "do shell script \"\(cmd)\" with administrator privileges"])
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
        if wifiAlwaysOn && watchdogTask == nil { startWatchdog() }
    }

    // MARK: - Updates (network is used only when the user clicks the button)

    @Published var updateStatus = ""

    func checkForUpdates(autoOpen: Bool = true) {
        Task {
            updateStatus = "Checking…"
            let url = URL(string: "https://api.github.com/repos/devygram/aegis-server/releases/latest")!
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let tag = obj?["tag_name"] as? String, let html = obj?["html_url"] as? String else {
                    updateStatus = "Could not read the release page."
                    return
                }
                let current = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
                if isNewer(tag, than: current) {
                    if autoOpen {
                        updateStatus = "New version \(tag) — opening the download page…"
                        NSWorkspace.shared.open(URL(string: html)!)
                    } else {
                        updateStatus = "Update available: \(tag) — click Check for Updates"
                    }
                } else {
                    updateStatus = "You're up to date (v\(current))."
                }
            } catch {
                updateStatus = "Could not check (offline?)."
            }
        }
    }

    // Compares "v1.2.1" style tags numerically.
    private func isNewer(_ tag: String, than current: String) -> Bool {
        func nums(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = nums(tag), b = nums(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
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
            do {
                try p.run(); caffeinateProcess = p; lastError = ""
                UserDefaults.standard.set(p.processIdentifier, forKey: "caffeinatePID")
            }
            catch { lastError = "Could not start caffeinate: \(error.localizedDescription)" }
        } else {
            caffeinateProcess?.terminate()
            caffeinateProcess = nil
            UserDefaults.standard.removeObject(forKey: "caffeinatePID")
        }
    }

    // Called on quit: undoes every system change the app is responsible for,
    // so a Mac that was kept awake goes back to normal sleep behavior.
    nonisolated static func cleanupOnQuit() {
        let d = UserDefaults.standard
        if d.bool(forKey: "sleepSet") {
            _ = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"])
            d.removeObject(forKey: "sleepSet")
        }
        if d.bool(forKey: "wifiSet") {
            _ = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "networkoversleep", "0"])
            d.removeObject(forKey: "wifiSet")
        }
        if let pid = d.object(forKey: "caffeinatePID") as? Int32 {
            kill(pid, SIGTERM)
            d.removeObject(forKey: "caffeinatePID")
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
