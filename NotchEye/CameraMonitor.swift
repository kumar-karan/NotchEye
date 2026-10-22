import Foundation
import AVFoundation
import CoreMediaIO

enum CameraEvent {
    case activated
    case deactivated
}

/// Event-driven camera monitor using CoreMediaIO property listeners.
/// Zero CPU when idle — the kernel calls us when state changes.
final class CameraMonitor {
    
    private let callback: (CameraEvent) -> Void
    private var isRunning = false
    private var lastKnownState: Bool = false
    private var monitoredDeviceIDs: [CMIOObjectID] = []
    private let monitorQueue = DispatchQueue(label: "dev.notcheye.camera-monitor", qos: .utility)
    
    // Debounce: macOS sometimes fires duplicate events
    private var lastEventTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.5
    
    init(callback: @escaping (CameraEvent) -> Void) {
        self.callback = callback
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        // Allow access to device properties
        enableDALAccess()
        
        // Discover all camera devices and attach listeners
        let devices = discoverCameraDevices()
        for deviceID in devices {
            attachPropertyListener(to: deviceID)
            monitoredDeviceIDs.append(deviceID)
        }
        
        // Also watch for new/removed devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil
        )
        
        // Check initial state
        let initialState = isAnyCameraActive()
        if initialState {
            lastKnownState = true
            callback(.activated)
        }
        
        print("[NotchEye] Camera monitoring started. Watching \(devices.count) device(s).")
    }
    
    func stopMonitoring() {
        guard isRunning else { return }
        isRunning = false
        
        for deviceID in monitoredDeviceIDs {
            removePropertyListener(from: deviceID)
        }
        monitoredDeviceIDs.removeAll()
        
        NotificationCenter.default.removeObserver(self)
        print("[NotchEye] Camera monitoring stopped.")
    }
    
    // MARK: - CoreMediaIO DAL Access
    
    private func enableDALAccess() {
        // Required on macOS 14+ to access camera device properties
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var allow: UInt32 = 1
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &property,
            0, nil,
            size,
            &allow
        )
    }
    
    // MARK: - Device Discovery
    
    private func discoverCameraDevices() -> [CMIOObjectID] {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        let status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &property,
            0, nil,
            &dataSize
        )
        
        guard status == noErr, dataSize > 0 else {
            print("[NotchEye] No CMIO devices found.")
            return []
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        
        CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &property,
            0, nil,
            dataSize,
            &dataSize,
            &devices
        )
        
        // Filter to only camera (video) devices
        return devices.filter { isVideoDevice($0) }
    }
    
    private func isVideoDevice(_ deviceID: CMIOObjectID) -> Bool {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        let status = CMIOObjectGetPropertyDataSize(deviceID, &property, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }
    
    // MARK: - Property Listeners (Zero-polling)
    
    private func attachPropertyListener(to deviceID: CMIOObjectID) {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        let status = CMIOObjectAddPropertyListenerBlock(
            deviceID,
            &property,
            monitorQueue
        ) { [weak self] _, _ in
            self?.handleStateChange()
        }
        
        if status != noErr {
            print("[NotchEye] Failed to attach listener to device \(deviceID): \(status)")
        }
    }
    
    private func removePropertyListener(from deviceID: CMIOObjectID) {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        CMIOObjectRemovePropertyListenerBlock(deviceID, &property, monitorQueue, { _, _ in })
    }
    
    // MARK: - State Change Handler
    
    private func handleStateChange() {
        let now = Date()
        guard now.timeIntervalSince(lastEventTime) > debounceInterval else { return }
        lastEventTime = now
        
        // Small delay to let macOS settle (OverSight pattern)
        monitorQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let active = self.isAnyCameraActive()
            guard active != self.lastKnownState else { return }
            
            self.lastKnownState = active
            let event: CameraEvent = active ? .activated : .deactivated
            
            DispatchQueue.main.async {
                self.callback(event)
            }
        }
    }
    
    // MARK: - State Query
    
    func isAnyCameraActive() -> Bool {
        let devices = discoverCameraDevices()
        return devices.contains { isDeviceRunning($0) }
    }
    
    private func isDeviceRunning(_ deviceID: CMIOObjectID) -> Bool {
        var property = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let status = CMIOObjectGetPropertyData(
            deviceID,
            &property,
            0, nil,
            dataSize,
            &dataSize,
            &isRunning
        )
        
        return status == noErr && isRunning != 0
    }
    
    // MARK: - Device Changes
    
    @objc private func deviceListChanged(_ notification: Notification) {
        monitorQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Remove old listeners
            for deviceID in self.monitoredDeviceIDs {
                self.removePropertyListener(from: deviceID)
            }
            self.monitoredDeviceIDs.removeAll()
            
            // Re-discover and re-attach
            let devices = self.discoverCameraDevices()
            for deviceID in devices {
                self.attachPropertyListener(to: deviceID)
                self.monitoredDeviceIDs.append(deviceID)
            }
            
            print("[NotchEye] Device list updated. Watching \(devices.count) device(s).")
        }
    }
}
