import AppKit
import SpriteKit

@MainActor
final class InteractivePetView: SKView {
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var onPrimaryClick: (() -> Void)?
    var onSecondaryClick: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onContextMenu: ((NSEvent) -> Void)?
    var onScaleDelta: ((Double) -> Void)?
    var allowsWindowDragging = true

    private var mouseDownLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?
    private var longPressWorkItem: DispatchWorkItem?
    private var hoverTrackingArea: NSTrackingArea?
    private var isPointerInside = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isPointerInside else { return }
        isPointerInside = true
        onHoverEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        guard isPointerInside else { return }
        isPointerInside = false
        onHoverExit?()
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
        let workItem = DispatchWorkItem { [weak self] in self?.onLongPress?() }
        longPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    override func mouseDragged(with event: NSEvent) {
        longPressWorkItem?.cancel()
        guard allowsWindowDragging, let start = mouseDownLocation, let origin = initialWindowOrigin, let window else { return }
        let current = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(x: origin.x + current.x - start.x, y: origin.y + current.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        longPressWorkItem?.cancel()
        guard let start = mouseDownLocation else { return }
        let distance = hypot(NSEvent.mouseLocation.x - start.x, NSEvent.mouseLocation.y - start.y)
        if distance < 4 {
            if event.clickCount >= 2 { onSecondaryClick?() }
            else { onPrimaryClick?() }
        }
        mouseDownLocation = nil
        initialWindowOrigin = nil
    }

    override func rightMouseDown(with event: NSEvent) { onContextMenu?(event) }

    override func scrollWheel(with event: NSEvent) {
        guard event.hasPreciseScrollingDeltas || abs(event.scrollingDeltaY) > 0 else { return }
        onScaleDelta?(Double(event.scrollingDeltaY) * 0.01)
    }

    override func magnify(with event: NSEvent) { onScaleDelta?(Double(event.magnification)) }
}
