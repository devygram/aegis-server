import SwiftUI

// App entry point: puts the app in the menu bar with no dock icon or main window.
@main
struct AegisServerApp: App {
    var body: some Scene {
        MenuBarExtra("Aegis Server", systemImage: "server.rack") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
