import SwiftUI
import AppKit

@main
struct MousyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StatsStore.shared

    var body: some Scene {
        MenuBarExtra {
            StatsView(store: store)
        } label: {
            Image(systemName: "cursorarrow.click.2")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pas d'icône dans le Dock : app "agent" vivant dans la barre des menus.
        NSApp.setActivationPolicy(.accessory)
        EventMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        StatsStore.shared.save()
    }
}
