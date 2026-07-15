import SwiftUI
import AppKit

@main
struct ArcMarkStudioApp: App {
    init() {
        // `swift run` launches from Terminal; explicitly bring the native window
        // forward so keyboard input is delivered to the editor, not the shell.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
    var body: some Scene {
        WindowGroup("ArcMark Studio") { ContentView() }
            .defaultSize(width: 1440, height: 900)
    }
}
