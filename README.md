# NotchEye 👁️

**A featherweight, native macOS camera indicator that lives in your MacBook's notch.**

Built specifically for Citrix Workspace / remote desktop users who miss the pinhole green LED indicator when working in fullscreen virtual machines.

---

## Highlights

- 🟢 **Instant Hardware Detection** — Event-driven via macOS `CoreMediaIO` property listeners (`kCMIODevicePropertyDeviceIsRunningSomewhere`). Zero polling, zero battery drain.
- 🏝️ **Native Dynamic Island / Notch Drop** — Smooth Core Animation spring drop-down hugging the physical MacBook notch, displaying "Camera Active" along with the detected application (e.g. `Citrix Viewer`).
- 💫 **Persistent Glowing Rim** — After 3.5 seconds, the expanded text pill smoothly morphs back into the notch, leaving a minimalist glowing emerald under-notch halo as long as the camera remains live.
- 🖥️ **Citrix Fullscreen Engine** — Configured with `.screenSaver` / `CGShieldingWindowLevel() + 1` and `.fullScreenAuxiliary` space collection. Sets `ignoresMouseEvents = YES` and `canBecomeKey = NO`, so 100% of mouse clicks and keystrokes pass directly to your remote desktop without interruption.
- 🔔 **System Banner & Audio Chime** — Dispatches a native macOS `UNUserNotificationCenter` banner and subtle Apple audio chime (`Tink`) on activation.
- 🎨 **Status Bar Accessory** — Clean menu bar icon with live camera status, manual demo test trigger (`Test Camera Alert`), color themes (Emerald Green, Privacy Amber, Electric Cyan), and toggles.

---

## Benchmark Results (Apple M1 Pro, macOS 26)

| Metric | Result | Notes |
| :--- | :--- | :--- |
| **Binary Size** | **124 KB** | Pure native Apple Clang Mach-O binary |
| **Bundle Size** | **132 KB** | Completely self-contained `.app` bundle |
| **Idle CPU Usage** | **0.0%** | Zero polling; kernel IPC callback only |
| **Idle RAM (RSS)** | **~49 MB** | Full AppKit / WindowServer connection |
| **Compile Time** | **< 2.0s** | Zero heavyweight toolchain dependencies |

---

## Build & Run

### 1. Build
```bash
./build.sh
```
Builds `NotchEye.app` in the local directory and signs it with an ad-hoc signature.

### 2. Run
```bash
open NotchEye.app
```
A discrete eye/camera symbol appears in your top menu bar.

### 3. Test the Animation Anytime
To preview the notch animation and sound immediately:
```bash
./NotchEye.app/Contents/MacOS/NotchEye --test
```
(Or click **Test Camera Alert (5s)** in the menu bar menu).

### 4. Quit
```bash
./NotchEye.app/Contents/MacOS/NotchEye --quit
```

### 5. Install to Applications (Optional)
```bash
cp -r NotchEye.app /Applications/
```

---

## Technical Architecture

```
┌────────────────────────────────────────────────────────┐
│              macOS Kernel / CoreMediaIO                │
│ (kCMIODevicePropertyDeviceIsRunningSomewhere callback)  │
└───────────────────────────┬────────────────────────────┘
                            │ (0% CPU Event)
                            ▼
┌────────────────────────────────────────────────────────┐
│                     CameraMonitor                      │
│ - Detects camera active state change                   │
│ - Inspects active processes (Citrix Viewer, Teams, etc)│
└───────────────────────────┬────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌───────────────────────────────┐ ┌──────────────────────┐
│       NotchOverlayWindow      │ │ UNUserNotification & │
│ - Level: ShieldingLevel + 1   │ │ NSSound Audio Chime  │
│ - Collection: FullScreenAux   │ └──────────────────────┘
│ - ignoresMouseEvents = YES    │
└───────────────┬───────────────┘
                ▼
┌───────────────────────────────┐
│        NotchIslandView        │
│ - Apple continuous squircle   │
│ - CASpringAnimation dropdown  │
│ - Persistent halo under notch │
└───────────────────────────────┘
```
