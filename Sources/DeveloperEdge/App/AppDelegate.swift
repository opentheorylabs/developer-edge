import SwiftUI
import AppKit
import Defaults
import LaunchAtLogin

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var refreshTimer: Timer?
    private weak var statusItem: NSStatusItem?
    private var rightClickMonitor: Any?

    func applicationDidFinishLaunching(_ note: Notification) {
        // Config is bootstrapped in the App's init (before the Store is built).
        // LSUIElement is set in Info.plist for the packaged app; enforce here too
        // so the SwiftUI lifecycle never shows a Dock icon.
        NSApplication.shared.setActivationPolicy(.accessory)
        // Force dark appearance app-wide so AppKit-backed controls (text fields in the
        // MenuBarExtra window) render light text · .preferredColorScheme alone doesn't reach them.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        registerLoginItemIfNeeded()
    }

    /// Performs the initial data load once the store exists. Called from the App scene.
    func bootstrap(_ store: Store) {
        store.checkAll()
        store.checkGraphToolInstalled()
        store.fetchJiraDisplayName()
        store.checkForUpdate()
    }

    // MARK: - Status item (right-click → Quit)

    /// Wires a right-click Quit menu onto the MenuBarExtra status item.
    func configureStatusItem(_ item: NSStatusItem) {
        statusItem = item
        guard let button = item.button else { return }
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if rightClickMonitor == nil {
            rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
                guard let self, let button = self.statusItem?.button,
                      event.window == button.window else { return event }
                self.showQuitMenu()
                return nil
            }
        }
    }

    private func showQuitMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit \(AppConfig.current.branding.appName)",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: - Refresh timer

    func checkAllIfNeeded(_ store: Store) {
        if let last = store.lastCheck, Date().timeIntervalSince(last) < 60 { return }
        store.checkAll()
    }

    func startRefreshTimer(_ store: Store) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self, weak store] _ in
            guard let store else { return }
            self?.checkAllIfNeeded(store)
        }
    }

    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Login item

    private func registerLoginItemIfNeeded() {
        // Enable launch-at-login once on first launch. Afterwards it stays
        // user-controllable via the Settings toggle · we never force it back on.
        guard !Defaults[.didRegisterLoginItem] else { return }
        LaunchAtLogin.isEnabled = true
        Defaults[.didRegisterLoginItem] = true
    }
}
