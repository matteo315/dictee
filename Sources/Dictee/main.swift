import AppKit
import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var pill: PillController!
    private var window: NSWindow?
    private let hotkeys = HotkeyMonitor()
    private var retryTimer: Timer?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = Store.shared
        if let model = store.modelPath {
            WhisperServer.shared.start(model: model, language: store.reglages.language, logDir: store.dir)
        }
        pill = PillController()
        setupStatusItem()
        Permissions.requestMicrophone()
        startHotkeys()
        activerDemarrageAuto()
        if store.isFirstLaunch || !Permissions.accessibility { openWindow() }
    }

    /// Dictée s'ouvre seule à l'allumage du Mac.
    /// On l'active une seule fois ; s'il la coupe ensuite dans Réglages, on ne la remet pas.
    private func activerDemarrageAuto() {
        let cle = "demarrageAutoActive"
        guard !UserDefaults.standard.bool(forKey: cle) else { return }
        if SMAppService.mainApp.status != .enabled { try? SMAppService.mainApp.register() }
        if SMAppService.mainApp.status == .enabled { UserDefaults.standard.set(true, forKey: cle) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WhisperServer.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openWindow()
        return true
    }

    // MARK: Raccourcis

    private func startHotkeys() {
        let d = Dictator.shared
        HotkeyMonitor.touche = Store.shared.reglages.touche
        hotkeys.onFnDown = { MainActor.assumeIsolated { d.fnDown() } }
        hotkeys.onFnUp = { MainActor.assumeIsolated { d.fnUp() } }
        hotkeys.onEscape = { MainActor.assumeIsolated { d.escape() } }
        hotkeys.onOtherKeyWhileFn = { MainActor.assumeIsolated { d.otherKeyWhileFn() } }
        if hotkeys.start() { return }
        // Sans l'autorisation Accessibilité, le Mac refuse : on la demande et on réessaie.
        Permissions.promptAccessibility()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { t.invalidate(); return }
                if self.hotkeys.start() { t.invalidate(); self.retryTimer = nil }
            }
        }
    }

    var hotkeysRunning: Bool { hotkeys.isRunning }

    // MARK: Icône en haut de l'écran

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Dictée")
        let menu = NSMenu()
        menu.addItem(withTitle: "Ouvrir Dictée", action: #selector(openWindowAction), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Dicter en mains libres", action: #selector(handsFreeAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Dictée", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        Dictator.shared.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                let name = phase == .idle ? "waveform" : "waveform.circle.fill"
                self?.statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Dictée")
            }
            .store(in: &bag)
    }

    @objc private func openWindowAction() { openWindow() }
    @objc private func handsFreeAction() { Dictator.shared.startHandsFree() }

    // MARK: Fenêtre

    func openWindow() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Dictée"
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 720, height: 520)
            w.contentView = NSHostingView(rootView: MainView())
            w.center()
            w.delegate = self
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
