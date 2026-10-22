import AppKit

/// Observable state for the notch overlay — pure AppKit, no SwiftUI.
final class NotchViewModel {
    var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else { return }
            onStateChange?(isActive)
        }
    }
    var hasNotch: Bool = true
    var onStateChange: ((Bool) -> Void)?
}

// MARK: - Notch Overlay Content View (Pure AppKit)

/// Renders the camera indicator glow and pill using Core Animation layers.
/// No SwiftUI — compiles fast and uses minimal memory.
final class NotchOverlayContentView: NSView {

    private let glowLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let pillView = CameraPillView()

    private var isShowingGlow = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        setupGlowLayer()
        setupBorderLayer()
        setupPillView()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds.insetBy(dx: 2, dy: 2)
        borderLayer.frame = bounds.insetBy(dx: 4, dy: 4)
        borderLayer.path = NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: borderLayer.frame.size),
            xRadius: 10,
            yRadius: 10
        ).cgPath
        CATransaction.commit()

        // Pill centered below the notch
        let pillSize = pillView.fittingSize
        pillView.frame = NSRect(
            x: (bounds.width - pillSize.width) / 2,
            y: -pillSize.height - 2,
            width: pillSize.width,
            height: pillSize.height
        )
    }

    private func setupGlowLayer() {
        glowLayer.type = .radial
        glowLayer.colors = [
            NSColor.systemGreen.withAlphaComponent(0.5).cgColor,
            NSColor.systemGreen.withAlphaComponent(0.1).cgColor,
            NSColor.clear.cgColor,
        ]
        glowLayer.locations = [0, 0.5, 1]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.opacity = 0
        glowLayer.cornerRadius = 10
        layer?.addSublayer(glowLayer)
    }

    private func setupBorderLayer() {
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.systemGreen.withAlphaComponent(0.8).cgColor
        borderLayer.lineWidth = 2
        borderLayer.opacity = 0
        layer?.addSublayer(borderLayer)
    }

    private func setupPillView() {
        pillView.alphaValue = 0
        addSubview(pillView)
    }

    // MARK: - Animate In/Out

    func showActive() {
        guard !isShowingGlow else { return }
        isShowingGlow = true

        // Fade in glow + border
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.35
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false

        glowLayer.add(fadeIn, forKey: "fadeIn")
        glowLayer.opacity = 1

        borderLayer.add(fadeIn, forKey: "fadeIn")
        borderLayer.opacity = 1

        // Start pulse animation on glow
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.7
        pulse.toValue = 1.0
        pulse.duration = 1.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = CACurrentMediaTime() + 0.35
        glowLayer.add(pulse, forKey: "pulse")

        // Show pill with spring-like animation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            pillView.animator().alphaValue = 1
        }

        // Auto-hide pill after 4 seconds (glow remains)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self, self.isShowingGlow else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.5
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.pillView.animator().alphaValue = 0
            }
        }
    }

    func showInactive() {
        guard isShowingGlow else { return }
        isShowingGlow = false

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = glowLayer.presentation()?.opacity ?? 1
        fadeOut.toValue = 0
        fadeOut.duration = 0.3
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false

        glowLayer.removeAnimation(forKey: "pulse")
        glowLayer.add(fadeOut, forKey: "fadeOut")
        glowLayer.opacity = 0

        borderLayer.add(fadeOut, forKey: "fadeOut")
        borderLayer.opacity = 0

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            pillView.animator().alphaValue = 0
        }
    }
}

// MARK: - Camera Pill Label

/// The small "📷 Camera Active" capsule that drops below the notch.
final class CameraPillView: NSView {

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "Camera Active")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        layer?.cornerRadius = 12
        layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.3).cgColor
        layer?.borderWidth = 0.5

        setupIcon()
        setupLabel()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var fittingSize: NSSize {
        let labelSize = label.fittingSize
        return NSSize(
            width: 12 + 14 + 6 + labelSize.width + 12,
            height: max(24, labelSize.height + 10)
        )
    }

    override func layout() {
        super.layout()
        let iconSize: CGFloat = 12
        iconView.frame = NSRect(
            x: 12,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        let labelX = iconView.frame.maxX + 5
        label.frame = NSRect(
            x: labelX,
            y: (bounds.height - label.fittingSize.height) / 2,
            width: label.fittingSize.width,
            height: label.fittingSize.height
        )
    }

    private func setupIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        iconView.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Camera")?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = .systemGreen
        addSubview(iconView)
    }

    private func setupLabel() {
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        addSubview(label)
    }
}

// MARK: - NSBezierPath → CGPath

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let kind = element(at: i, associatedPoints: &points)
            switch kind {
            case .moveTo:    path.move(to: points[0])
            case .lineTo:    path.addLine(to: points[0])
            case .curveTo:   path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}
