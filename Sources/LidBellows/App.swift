import AppKit
import SwiftUI

@main
struct LidBellowsApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("LidBellows", id: "main") {
            ContentView()
                .environmentObject(Engine.shared)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Lets a bare `swift run` binary take keyboard focus like a bundled app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        Engine.shared.start()
    }

    func applicationDidResignActive(_ notification: Notification) {
        // Key-up events go to the other app, so nothing would ever stop the held notes.
        Engine.shared.releaseAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
