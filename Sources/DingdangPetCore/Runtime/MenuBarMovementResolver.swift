import Foundation

public struct MenuBarMovementStep: Equatable, Sendable {
    public var x: Double
    public var direction: Int
    public var reachedBoundary: Bool
    public var crossedNotch: Bool

    public init(x: Double, direction: Int, reachedBoundary: Bool, crossedNotch: Bool) {
        self.x = x
        self.direction = direction
        self.reachedBoundary = reachedBoundary
        self.crossedNotch = crossedNotch
    }
}

public struct MenuBarVerticalGeometry: Equatable, Sendable {
    public var bottom: Double
    public var height: Double

    public init(bottom: Double, height: Double) {
        self.bottom = bottom
        self.height = height
    }
}

public enum MenuBarMovementResolver {
    public static func verticalGeometry(
        screenMaxY: Double,
        visibleFrameMaxY: Double,
        systemThickness: Double
    ) -> MenuBarVerticalGeometry {
        let reservedHeight = max(0, screenMaxY - min(screenMaxY, visibleFrameMaxY))
        let height = max(0, max(systemThickness, reservedHeight))
        return MenuBarVerticalGeometry(bottom: screenMaxY - height, height: height)
    }

    public static func shouldAdvance(
        isPerformingBehavior: Bool,
        currentAnimationName: String?,
        locomotionAnimationName: String?
    ) -> Bool {
        !isPerformingBehavior && locomotionAnimationName != nil && currentAnimationName == locomotionAnimationName
    }

    public static func bounds(
        screenMinX: Double,
        screenMaxX: Double,
        panelWidth: Double,
        leftMargin: Double,
        rightMargin: Double
    ) -> ClosedRange<Double> {
        let lower = screenMinX + max(0, leftMargin)
        let upper = max(lower, screenMaxX - max(0, rightMargin) - max(0, panelWidth))
        return lower...upper
    }

    public static func advance(
        currentX: Double,
        direction: Int,
        speed: Double,
        delta: Double,
        bounds: ClosedRange<Double>,
        panelWidth: Double,
        notch: ClosedRange<Double>? = nil,
        skipNotch: Bool = false
    ) -> MenuBarMovementStep {
        let normalizedDirection = direction >= 0 ? 1 : -1
        var nextX = currentX + Double(normalizedDirection) * max(0, speed) * max(0, delta)

        if nextX <= bounds.lowerBound {
            return MenuBarMovementStep(x: bounds.lowerBound, direction: 1, reachedBoundary: true, crossedNotch: false)
        }
        if nextX >= bounds.upperBound {
            return MenuBarMovementStep(x: bounds.upperBound, direction: -1, reachedBoundary: true, crossedNotch: false)
        }

        var crossedNotch = false
        if skipNotch, let notch {
            if normalizedDirection > 0,
               currentX + panelWidth <= notch.lowerBound,
               nextX + panelWidth > notch.lowerBound,
               notch.upperBound <= bounds.upperBound {
                nextX = notch.upperBound
                crossedNotch = true
            } else if normalizedDirection < 0,
                      currentX >= notch.upperBound,
                      nextX < notch.upperBound,
                      notch.lowerBound - panelWidth >= bounds.lowerBound {
                nextX = notch.lowerBound - panelWidth
                crossedNotch = true
            }
        }

        return MenuBarMovementStep(
            x: min(max(nextX, bounds.lowerBound), bounds.upperBound),
            direction: normalizedDirection,
            reachedBoundary: false,
            crossedNotch: crossedNotch
        )
    }
}
