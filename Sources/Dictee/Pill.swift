import AppKit
import SwiftUI
import Combine

/// La barre collée au bord gauche de l'écran.
@MainActor
final class PillUI: ObservableObject {
    @Published var hovered = false
}

/// Une fenêtre qui ne prend jamais le clavier : le texte doit aller dans l'appli d'en dessous.
final class PillPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class HoverView: NSView {
    var onHover: ((Bool) -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class PillController {
    private let panel: PillPanel
    private let ui = PillUI()
    private var bag = Set<AnyCancellable>()

    // Tailles de la fenêtre selon l'état (la partie transparente ne gêne pas : elle est rognée au plus juste).
    private let collapsed = NSSize(width: 16, height: 64)
    private let hover = NSSize(width: 150, height: 64)
    private let active = NSSize(width: 132, height: 40)

    init() {
        panel = PillPanel(contentRect: NSRect(origin: .zero, size: collapsed),
                          styleMask: [.nonactivatingPanel, .borderless],
                          backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let root = HoverView(frame: NSRect(origin: .zero, size: collapsed))
        let host = FirstMouseHostingView(rootView: PillView(ui: ui))
        host.frame = root.bounds
        host.autoresizingMask = [.width, .height]
        root.addSubview(host)
        root.onHover = { [weak self] inside in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.ui.hovered = inside
                self.layout(Dictator.shared.phase)
            }
        }
        panel.contentView = root

        Dictator.shared.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                if phase == .idle {
                    self.ui.hovered = self.panel.frame.contains(NSEvent.mouseLocation) && self.ui.hovered
                }
                self.layout(phase)
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layout(Dictator.shared.phase) }
            .store(in: &bag)

        // La barre suit l'écran où se trouve la souris.
        Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let s = Self.mouseScreen()
                if s != self.currentScreen { self.layout(Dictator.shared.phase) }
            }
            .store(in: &bag)

        layout(.idle)
        panel.orderFrontRegardless()
    }

    private var currentScreen: NSScreen?

    private static func mouseScreen() -> NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func layout(_ phase: Dictator.Phase) {
        guard let screen = Self.mouseScreen() else { return }
        currentScreen = screen
        let vf = screen.visibleFrame
        let size: NSSize
        switch phase {
        case .idle: size = ui.hovered ? hover : collapsed
        case .listening, .transcribing: size = active
        }
        let rect = NSRect(x: vf.minX, y: (vf.midY - size.height / 2).rounded(), width: size.width, height: size.height)
        panel.setFrame(rect, display: true)
        panel.orderFrontRegardless()
    }
}

struct PillView: View {
    @ObservedObject var ui: PillUI
    @ObservedObject private var d = Dictator.shared

    var body: some View {
        ZStack(alignment: .leading) {
            switch d.phase {
            case .idle:
                if ui.hovered { hoverContent } else { collapsedBar }
            case .listening, .transcribing:
                activeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var collapsedBar: some View {
        Capsule()
            .fill(Color.black.opacity(0.88))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
            .frame(width: 5, height: 44)
            .padding(.leading, 4)
    }

    private var hoverContent: some View {
        HStack(spacing: 8) {
            Button { d.startHandsFree() } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .help("Dicter en mains libres")

            HStack(spacing: 5) {
                Text("Dicter")
                Text("\(Store.shared.reglages.touche.symbole) \(Store.shared.reglages.touche.symbole)").fontWeight(.semibold)
            }
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(Color.black))
        }
        .padding(.leading, 6)
    }

    private var activeContent: some View {
        HStack(spacing: 6) {
            Button { d.cancelFromButton() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.16)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .help("Annuler (Échap)")

            ZStack {
                if d.phase == .transcribing {
                    ProgressView().controlSize(.mini).colorScheme(.dark)
                } else {
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(Array(d.levels.suffix(14).enumerated()), id: \.offset) { _, v in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 2, height: 2 + v * 12)
                        }
                    }
                    .animation(.linear(duration: 0.08), value: d.levels)
                }
            }
            .frame(width: 54, height: 18)

            Button { d.finishFromButton() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white))
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .help("Terminer et coller (\(Store.shared.reglages.touche.nom))")
            .opacity(d.phase == .transcribing ? 0.35 : 1)
            .disabled(d.phase == .transcribing)
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
        .padding(.leading, 6)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
