import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cameraMonitor: CameraMonitor?
    private var notchOverlay: NotchOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
        setupNotchOverlay()
        requestNotificationPermission()
        startCameraMonitoring()
    }

    // MARK: - Menu Bar

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "NotchEye")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "NotchEye", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let cameraStatusItem = NSMenuItem(title: "Camera: Off", action: nil, keyEquivalent: "")
        cameraStatusItem.isEnabled = false
        cameraStatusItem.tag = 100
        menu.addItem(cameraStatusItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit NotchEye", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    // MARK: - Notch Overlay

    private func setupNotchOverlay() {
        notchOverlay = NotchOverlayController()
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("[NotchEye] Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Camera Monitoring

    private func startCameraMonitoring() {
        cameraMonitor = CameraMonitor { [weak self] event in
            DispatchQueue.main.async {
                self?.handleCameraEvent(event)
            }
        }
        cameraMonitor?.startMonitoring()
    }

    private func handleCameraEvent(_ event: CameraEvent) {
        switch event {
        case .activated:
            updateMenuBarStatus(active: true)
            notchOverlay?.showCameraActive()
            sendNotification(title: "📷 Camera On", body: "Your camera is now active")
            playAlertSound()

        case .deactivated:
            updateMenuBarStatus(active: false)
            notchOverlay?.showCameraInactive()
        }
    }

    private func updateMenuBarStatus(active: Bool) {
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = active ? "Camera: 🟢 Active" : "Camera: Off"
        }

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "NotchEye")
            image?.isTemplate = !active

            if active {
                button.contentTintColor = .systemGreen
            } else {
                button.contentTintColor = nil
            }
            button.image = image
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "camera-state-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func playAlertSound() {
        NSSound(named: "Tink")?.play()
    }

    @objc private func quitApp() {
        cameraMonitor?.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
