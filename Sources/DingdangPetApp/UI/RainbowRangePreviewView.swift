import AppKit
import QuartzCore

@MainActor
final class RainbowRangePreviewView: NSView {
    private let gradientLayer = CAGradientLayer()
    private let revealLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        gradientLayer.colors = [
            NSColor.systemRed.cgColor,
            NSColor.systemOrange.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemGreen.cgColor,
            NSColor.systemCyan.cgColor,
            NSColor.systemBlue.cgColor,
            NSColor.systemPurple.cgColor
        ]
        gradientLayer.locations = [0, 0.16, 0.32, 0.5, 0.66, 0.82, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        revealLayer.fillColor = nil
        revealLayer.strokeColor = NSColor.white.cgColor
        revealLayer.lineWidth = 4
        revealLayer.lineCap = .round
        gradientLayer.mask = revealLayer
        layer?.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        revealLayer.frame = bounds
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 3, y: 3))
        path.addLine(to: CGPoint(x: max(3, bounds.width - 3), y: 3))
        revealLayer.path = path
    }

    func play() {
        layoutSubtreeIfNeeded()
        revealLayer.removeAllAnimations()
        revealLayer.strokeEnd = 1
        let reveal = CABasicAnimation(keyPath: "strokeEnd")
        reveal.fromValue = 0
        reveal.toValue = 1
        reveal.duration = 0.9
        reveal.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        revealLayer.add(reveal, forKey: "rainbow-range-reveal")

        layer?.removeAllAnimations()
        layer?.opacity = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 1.15
        fade.duration = 0.55
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        layer?.add(fade, forKey: "rainbow-range-fade")
    }
}
