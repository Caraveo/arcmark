import SwiftUI
import AppKit

@main
struct ArcMarkStudioApp: App {
    @NSApplicationDelegateAdaptor(ArcMarkApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        WindowGroup("ArcMark Studio") { ContentView() }
            .defaultSize(width: 1440, height: 900)
    }
}

/// `swift run` inherits Terminal as its active application.  Activating from
/// `App.init` is too early: the SwiftUI window has not been created yet, so
/// Terminal can retain keyboard focus.  Activate after launch and again after
/// the first run-loop turn, when the editor window is available.
final class ArcMarkApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.module.url(forResource: "app-icon", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        bringEditorToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.bringEditorToFront()
        }
    }

    private func bringEditorToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        ArcMarkDocumentOpenCoordinator.shared.open(urls)
    }
}

/// Bridges Finder and Launch Services open-file events into SwiftUI. The
/// coordinator retains the last requested URL so a document opened while the
/// app is launching is delivered after the editor view has appeared.
final class ArcMarkDocumentOpenCoordinator: ObservableObject {
    static let shared = ArcMarkDocumentOpenCoordinator()
    @Published private(set) var requestedURL: URL?

    func open(_ urls: [URL]) {
        DispatchQueue.main.async {
            self.requestedURL = urls.last
        }
    }
}
