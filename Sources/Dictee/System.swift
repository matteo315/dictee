import AppKit
import AVFoundation
import ApplicationServices

/// Écoute la touche choisie (Ctrl par défaut) et Échap partout sur le Mac. (Les noms « fn » restent dans le code.)
final class HotkeyMonitor {
    /// La touche choisie dans Réglages (mise à jour par Store).
    static var touche: Touche = .ctrl

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    /// Renvoie vrai si Échap a servi (on l'avale alors pour l'appli en dessous).
    var onEscape: (() -> Bool)?
    var onOtherKeyWhileFn: (() -> Void)?

    private var tap: CFMachPort?
    private var fnIsDown = false

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                        callback: callback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let src = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        tap = t
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .flagsChanged {
            let t = HotkeyMonitor.touche
            if t.keycodes.contains(keycode) {
                let down = event.flags.rawValue & t.bit != 0
                if down != fnIsDown {
                    fnIsDown = down
                    if down { onFnDown?() } else { onFnUp?() }
                }
            } else if fnIsDown {
                onOtherKeyWhileFn?() // Ctrl + Cmd, Ctrl + Option…
            }
        } else if type == .keyDown {
            if keycode == 53, let onEscape, onEscape() { return nil }
            if fnIsDown { onOtherKeyWhileFn?() } // Ctrl + lettre = un raccourci, pas une dictée
        } else if fnIsDown {
            onOtherKeyWhileFn?() // Ctrl + clic
        }
        return Unmanaged.passUnretained(event)
    }
}

/// Colle le texte dans l'appli ouverte, puis remet le presse-papiers d'avant.
enum Paster {
    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let saved: [[NSPasteboard.PasteboardType: Data]] = (pb.pasteboardItems ?? []).map { item in
            var d: [NSPasteboard.PasteboardType: Data] = [:]
            for t in item.types { if let v = item.data(forType: t) { d[t] = v } }
            return d
        }
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ours = pb.changeCount

        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pb.changeCount == ours, !saved.isEmpty else { return }
            pb.clearContents()
            let items: [NSPasteboardItem] = saved.map { dict in
                let it = NSPasteboardItem()
                for (t, v) in dict { it.setData(v, forType: t) }
                return it
            }
            pb.writeObjects(items)
        }
    }
}

enum Permissions {
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var inputMonitoring: Bool { CGPreflightListenEventAccess() }
    static var microphone: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }

    static func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Réglage « Appuyer sur 🌐 pour » : 0 = ne rien faire. Absent = valeur d'usine (emojis).
    static var fnOpensSomething: Bool {
        let v = UserDefaults(suiteName: "com.apple.HIToolbox")?.object(forKey: "AppleFnUsageType") as? Int
        return v != 0
    }

    static func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func requestInputMonitoring() { _ = CGRequestListenEventAccess() }

    static func requestMicrophone() {
        if microphone == .notDetermined { AVCaptureDevice.requestAccess(for: .audio) { _ in } }
    }

    /// pane : Privacy_Accessibility, Privacy_ListenEvent, Privacy_Microphone
    static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
