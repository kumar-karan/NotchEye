import AppKit

/// Manages the floating overlay window anchored to the MacBook notch.
/// Uses the NotchDrop pattern: borderless, transparent,
/// non-activating panel that floats over everything including Citrix fullscreen.
final class NotchOverlayController {

    private var window: NotchWindow?
    private var contentView: NotchOverlayContentView?
    private var viewModel = NotchViewModel()

    private var screenObserver: Any?

    init() {
        createWindow()
        observeScreenChanges()
        viewModel.onStateChange = { [weak self] active in
            if active {
                self?.contentView?.showActive()
            } else {
                self?.contentView?.showInactive()
            }
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Window Creation

    private func createWindow() {
        guard let screen = NSScreen.builtInScreen else {
            createFallbackWindow()
            return
        }

        if let notchRect = screen.notchFrame {
            let padding: CGFloat = 6
            let windowRect = NSRect(
                x: notchRect.origin.x - padding,
                y: notchRect.origin.y - padding - 20,
                width: notchRect.width + padding * 2,
                height: notchRect.height + padding * 2 + 20
            )
            setupWindow(frame: windowRect, screen: screen)
        } else {
            createFallbackWindow()
        }
    }

    private func createFallbackWindow() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let capsuleWidth: CGFloat = 220
        let capsuleHeight: CGFloat = 56

        let windowRect = NSRect(
            x: screen.frame.midX - capsuleWidth / 2,
            y: screen.frame.maxY - capsuleHeight - 4,
            width: capsuleWidth,
            height: capsuleHeight
        )

        viewModel.hasNotch = false
        setupWindow(frame: windowRect, screen: screen)
    }

    private func setupWindow(frame: NSRect, screen: NSScreen) {
        let win = NotchWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.isMovable = false
        win.ignoresMouseEvents = true
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.animationBehavior = .none

        // Float over EVERYTHING including Citrix fullscreen
        win.level = NSWindow.Level(Int(CGShieldingWindowLevel()) + 1)

        // Visible on all Spaces, doesn't appear in Mission Control or Cmd+Tab
        win.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        let content = NotchOverlayContentView(frame: NSRect(origin: .zero, size: frame.size))
        win.contentView = content
        self.contentView = content

        win.orderFrontRegardless()
        self.window = win
    }

    // MARK: - Screen Changes

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.rebuildWindow()
            }
        }
    }

    private func rebuildWindow() {
        let wasActive = viewModel.isActive
        window?.close()
        window = nil
        contentView = nil
        createWindow()

        if wasActive {
            contentView?.showActive()
        }
    }

    // MARK: - Public API

    func showCameraActive() {
        viewModel.isActive = true
    }

    func showCameraInactive() {
        viewModel.isActive = false
    }
}

// MARK: - NotchWindow

/// Minimal NSWindow subclass that refuses to become key/main,
/// ensuring it never steals focus from Citrix or other apps.
final class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - NSScreen Notch Detection

extension NSScreen {

    static var builtInScreen: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    var notchFrame: NSRect? {
        guard safeAreaInsets.top > 0 else { return nil }

        guard let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea else { return nil }

        let notchWidth = rightArea.minX - leftArea.maxX
        let notchHeight = safeAreaInsets.top

        guard notchWidth > 0, notchHeight > 0 else { return nil }

        return NSRect(
            x: frame.origin.x + leftArea.maxX,
            y: frame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }
}
