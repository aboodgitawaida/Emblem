import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NowPlayingModel()
    private var statusItem: NSStatusItem!
    private var animator: StatusIconAnimator!
    private var panel: PlayerPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Natural width: macOS sizes its press pill from the item's slot, and a fixed length made the
        // slot (and that pill) much wider than the system Now Playing item's.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "OVOBarNowPlaying"
        let button = statusItem.button!
        animator = StatusIconAnimator(button: button)

        // Handle presses on the icon ourselves, before the button's own click tracking runs.
        // That tracking un-highlights the button on mouse-up, which made the "pressed" look
        // vanish while the player was still open. Like the system item, it opens on press.
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button, event.window === button.window else { return event }
                if event.type == .rightMouseDown || event.modifierFlags.contains(.control) { self.showMenu() }
                else { self.togglePanel() }
                return nil
            }
        }

        model.$isDrakeMode.removeDuplicates().sink { [weak self] drake in
            self?.animator.setOwl(drake)
        }.store(in: &cancellables)

        model.start()
        registerLoginItemOnFirstLaunch()
    }

    private func togglePanel() {
        if let panel, panel.isVisible { panel.dismiss(); return }
        // If something else closed it during this same click, don't pop it straight back open.
        if let panel, Date().timeIntervalSince(panel.lastDismissed) < 0.3 { return }
        showPanel()
    }

    private func showPanel() {
        guard let button = statusItem.button, let window = button.window else { return }
        let panel = self.panel ?? PlayerPanel(model: model)
        self.panel = panel
        panel.onDismiss = { [weak self] in self?.releaseTimer?.invalidate(); self?.setPressed(false) }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: anchor, menuBarBottom: window.frame.minY)
        setPressedAfterRelease()
    }

    private var releaseTimer: Timer?

    /// While the mouse is held, macOS draws its own (larger) press pill over the item. Like the system
    /// item, show our "open" pill only once the button is released, so the two never overlap.
    private func setPressedAfterRelease() {
        releaseTimer?.invalidate()
        guard NSEvent.pressedMouseButtons != 0 else { setPressed(true); return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard NSEvent.pressedMouseButtons == 0 else { return }
                timer.invalidate()
                guard let self, self.panel?.isVisible == true else { return }
                self.setPressed(true)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        releaseTimer = t
    }

    private lazy var pill = PillWindow()

    /// The "open" pill behind the icon, matching the system Now Playing item's while its module is open.
    /// macOS draws its own (wider) press pill only while the mouse is held, so ours appears on release.
    private func setPressed(_ pressed: Bool) {
        guard let button = statusItem.button, let itemWindow = button.window else { return }
        if pressed {
            let item = button.accessibilityFrame()
            pill.show(centeredOn: NSPoint(x: item.midX, y: itemWindow.frame.midY), behind: itemWindow,
                      dark: button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        } else {
            pill.hide()
        }
    }

    // MARK: Right-click menu

    private func showMenu() {
        let menu = NSMenu()
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OVOBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        panel?.dismiss()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // keep left-click for the player
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { Log.write("login item change failed: \(error)") }
    }

    private func registerLoginItemOnFirstLaunch() {
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch { Log.write("login item registration failed: \(error)") }
    }

    func applicationWillTerminate(_ notification: Notification) { model.system?.stop() }
}

/// Root of the panel: the player card pinned to the top of a fixed, transparent canvas
/// (room for the card's soft shadow; the empty area lets clicks through).
struct PanelRoot: View {
    @ObservedObject var model: NowPlayingModel

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(model: model)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            Spacer(minLength: 0)
        }
        .padding(.top, PlayerPanel.shadowInset / 2)
        .frame(width: PlayerPanel.size.width, height: PlayerPanel.size.height, alignment: .top)
    }
}

/// Borderless panel under the menu bar item, like the system Now Playing module.
@MainActor
final class PlayerPanel: NSPanel {
    static let shadowInset: CGFloat = 40
    static let size = NSSize(width: PlayerView.width + shadowInset * 2, height: 230)

    var onDismiss: (() -> Void)?
    private var monitors: [Any] = []
    private var anchor: NSRect = .zero
    private(set) var lastDismissed = Date.distantPast
    private let model: NowPlayingModel
    private let hosting: NSHostingView<PanelRoot>

    init(model: NowPlayingModel) {
        self.model = model
        hosting = NSHostingView(rootView: PanelRoot(model: model))
        hosting.sizingOptions = []
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false          // the card draws its own shadow
        isReleasedWhenClosed = false
        hidesOnDeactivate = false   // a menu bar app is never the active app
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = hosting
        NotificationCenter.default.addObserver(forName: .dismissPlayer, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    override var canBecomeKey: Bool { true }

    func show(below anchor: NSRect, menuBarBottom: CGFloat) {
        self.anchor = anchor
        let size = Self.size
        setContentSize(size)
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        // Like the system module: card's left edge lines up with the icon's, just under the menu bar.
        // Measured on the system module: 1pt below the menu bar, left edge on the item's slot.
        let cardTop = menuBarBottom - 1
        var cardLeft = anchor.minX
        cardLeft = min(max(cardLeft, visible.minX + 8), visible.maxX - PlayerView.width - 8)
        setFrameOrigin(NSPoint(x: cardLeft - Self.shadowInset, y: cardTop + Self.shadowInset / 2 - size.height))
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 1 }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                // A click on our own menu bar icon is handled by its action (which toggles), not here.
                guard let self, !self.anchor.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
                self.dismiss()
            }
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] e in
            guard e.keyCode == 53 else { return e }   // Escape
            MainActor.assumeIsolated { self?.dismiss() }
            return nil
        }) { monitors.append(m) }
    }

    func dismiss() {
        guard isVisible else { return }
        lastDismissed = Date()
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        orderOut(nil)
        onDismiss?()
    }
}

/// The system Now Playing item's "open" pill, measured at 2× from screenshots
/// on a 33pt notch menu bar: 37×23pt, centred on the icon, ~15% white over the black bar.
/// (macOS's press pill while the mouse is held is wider, ~57pt; ours appears after release.)
enum Pill {
    static let open = NSSize(width: 37, height: 23)
}

/// A see-through window just behind the status item that draws the pill. It ignores the mouse,
/// so clicks still reach the icon.
@MainActor
final class PillWindow: NSPanel {
    private let pill = NSView()

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Pill.open),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        pill.wantsLayer = true
        pill.layer?.cornerRadius = Pill.open.height / 2
        pill.layer?.cornerCurve = .continuous
        contentView = pill
    }

    func show(centeredOn center: NSPoint, behind itemWindow: NSWindow, dark: Bool) {
        pill.layer?.backgroundColor = (dark ? NSColor.white.withAlphaComponent(0.155)
                                            : NSColor.black.withAlphaComponent(0.1)).cgColor
        setFrame(NSRect(x: center.x - Pill.open.width / 2, y: center.y - Pill.open.height / 2,
                        width: Pill.open.width, height: Pill.open.height), display: true)
        level = itemWindow.level
        alphaValue = 0
        order(.below, relativeTo: itemWindow.windowNumber)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 1 }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in
            MainActor.assumeIsolated { if self?.alphaValue == 0 { self?.orderOut(nil) } }
        })
    }
}
