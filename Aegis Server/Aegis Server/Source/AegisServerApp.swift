import SwiftUI
import ServiceManagement

// Releases the system settings the app set (sleep, Wi-Fi, caffeinate) when the user quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        SystemController.cleanupOnQuit()
    }
}

// App entry point: puts the app in the menu bar with no dock icon or main window.
@main
struct AegisServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Aegis Server", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
