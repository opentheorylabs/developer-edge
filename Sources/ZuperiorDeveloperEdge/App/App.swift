import SwiftUI
import AppKit
import MenuBarExtraAccess

@main
struct ZuperiorDeveloperEdgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store()
    @State private var isPanelPresented = false

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
                .preferredColorScheme(.dark)
                .task { appDelegate.bootstrap(store) }
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        // `menuBarExtraAccess` must be the FIRST modifier after `MenuBarExtra`
        // (it is an extension on MenuBarExtra, not Scene).
        .menuBarExtraAccess(isPresented: $isPanelPresented) { statusItem in
            // Re-route right-clicks to a Quit menu, matching the old AppKit behavior.
            appDelegate.configureStatusItem(statusItem)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: isPanelPresented) { presented in
            guard presented else {
                appDelegate.stopRefreshTimer()
                return
            }
            store.popoverSession = UUID()
            store.fetchJiraDisplayName()
            appDelegate.checkAllIfNeeded(store)
            appDelegate.startRefreshTimer(store)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Status-bar template icon. Reuses the bundled `icon.png` (falls back to an SF Symbol).
    static let menuBarIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = true
            return img
        }
        let fallback = NSImage(systemSymbolName: "z.circle.fill", accessibilityDescription: "Zuperior")!
        fallback.isTemplate = true
        return fallback
    }()
}
